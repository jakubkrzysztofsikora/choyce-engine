class_name SandboxKitBridge
extends Node
## Adapter wiring the couch co-op sandbox kit autoloads (Build / PlayerRegistry
## / Saves, migrated from rpg-asserts) into choyce domain infrastructure:
##
##   kit signal                      -> choyce reaction
##   ------------------------------------------------------------------
##   BuildSystem.block_placed        -> WorldEditedEvent("node_added") on the
##                                      DomainEventBus + debounced persistence
##   BuildSystem.block_removed       -> WorldEditedEvent("node_removed") + save
##   PlayerRegistry.player_joined    -> "SandboxKitPlayerJoined" bus event and
##                                      Session.add_player("sandbox_p<id>")
##   PlayerRegistry.player_left      -> "SandboxKitPlayerLeft" bus event
##   SaveSystem.saved                -> "SandboxKitSaveWritten" bus event
##
## The bridge is owned by GameplayRuntime for the duration of one sandbox-kit
## session and receives the composition-root services via setup_services()
## (injected from main.gd). It never touches src/domain internals beyond the
## public event/state types.

const SAVE_DEBOUNCE_SEC := 0.5

var _event_bus: DomainEventBus = null
var _persistence: SandboxPersistenceService = null
var _world_id := ""
var _session_ref: Session = null
var _max_players := PlayerRegistrySystem.MAX_PLAYERS
var _save_pending := false

# Kit block ids are palette StringNames; SandboxState wants plain strings.
# World position -> cell uses floor() so restore (cell + 0.5 centre) round-trips.


func setup_services(event_bus: DomainEventBus, persistence: SandboxPersistenceService) -> void:
	_event_bus = event_bus
	_persistence = persistence
	var build := BuildSystem.instance
	if build != null:
		_reconnect(build.block_placed, _on_block_placed)
		_reconnect(build.block_removed, _on_block_removed)
	var reg := PlayerRegistrySystem.instance
	if reg != null:
		_reconnect(reg.player_joined, _on_player_joined)
		_reconnect(reg.player_left, _on_player_left)
	var saves := SaveSystem.instance
	if saves != null:
		_reconnect(saves.saved, _on_saves_saved)


func set_world_id(world_id: String) -> void:
	_world_id = world_id


func set_session(session: Session) -> void:
	_session_ref = session


func apply_safety_policy(max_players: int, max_blocks_per_player: int, allow_joins: bool) -> void:
	_max_players = clampi(max_players, 1, PlayerRegistrySystem.MAX_PLAYERS)
	var build := BuildSystem.instance
	if build != null:
		if max_blocks_per_player > 0:
			build.max_blocks_per_player = max_blocks_per_player
		else:
			# 0 would be a fail-open in a kid-safety engine: clamp to 1 instead
			# of silently retaining the previous cap. Caller intent is "deny".
			build.max_blocks_per_player = 1
	var reg := PlayerRegistrySystem.instance
	if reg != null:
		reg.accepting_joins = allow_joins
	_enforce_roster_cap()


## Build records -> SandboxState cells. Cell = floor(world pos); the restore
## path adds back the +0.5 block-centre offset.
func snapshot_state() -> SandboxState:
	var build := BuildSystem.instance
	if build == null:
		return null
	var state := SandboxState.new()
	state.world_id = _world_id
	for rec in build.all_records():
		var pos: Vector3 = rec["pos"]
		state.placed_blocks.append({
			"cell": Vector3i(floori(pos.x), floori(pos.y), floori(pos.z)),
			"kind": String(rec["id"]),
		})
	state.saved_at_unix = int(Time.get_unix_time_from_system())
	return state


## SandboxState cells -> kit records. clear_all() first: place_bulk does not
## dedupe, and the level's starter structure would collide occupancy otherwise.
func restore_snapshot(state: SandboxState) -> int:
	var build := BuildSystem.instance
	if build == null or state == null or state.placed_blocks.is_empty():
		return 0
	build.clear_all()
	var records: Array = []
	for entry in state.placed_blocks:
		if not (entry is Dictionary):
			continue
		var cell_raw: Variant = entry.get("cell", null)
		var kind := StringName(String(entry.get("kind", "")))
		if cell_raw is Vector3i and kind != &"":
			records.append({
				"id": String(kind),
				"by": 0,
				"pos": Vector3(cell_raw) + Vector3.ONE * 0.5,
				"rot": Vector3.ZERO,
				"tint": Color.WHITE,
			})
	return build.place_bulk(records, 0)


func dispose() -> void:
	# Flush any pending debounced save BEFORE disconnecting callables so the
	# last 0.5 s of edits aren't silently lost on session end / crash.
	_flush_save_sync()
	var build := BuildSystem.instance
	if build != null:
		if build.block_placed.is_connected(_on_block_placed):
			build.block_placed.disconnect(_on_block_placed)
		if build.block_removed.is_connected(_on_block_removed):
			build.block_removed.disconnect(_on_block_removed)
	var reg := PlayerRegistrySystem.instance
	if reg != null:
		if reg.player_joined.is_connected(_on_player_joined):
			reg.player_joined.disconnect(_on_player_joined)
		if reg.player_left.is_connected(_on_player_left):
			reg.player_left.disconnect(_on_player_left)
	var saves := SaveSystem.instance
	if saves != null and saves.saved.is_connected(_on_saves_saved):
		saves.saved.disconnect(_on_saves_saved)
	_session_ref = null
	_event_bus = null
	_persistence = null


## --- handlers ---------------------------------------------------------------

func _on_block_placed(block_id: StringName, pos: Vector3, player_id: int) -> void:
	_emit_world_edited("node_added", block_id, pos, player_id)
	_schedule_save()


func _on_block_removed(block_id: StringName, pos: Vector3, player_id: int) -> void:
	_emit_world_edited("node_removed", block_id, pos, player_id)
	_schedule_save()


func _emit_world_edited(edit_type: String, block_id: StringName, pos: Vector3, player_id: int) -> void:
	if _event_bus == null:
		return
	var ev := WorldEditedEvent.new(
		_world_id, edit_type, "sandbox_player_%d" % maxi(player_id, 0))
	ev.target_node_id = "%s:%s@%d_%d_%d" % [
		edit_type, block_id, floori(pos.x), floori(pos.y), floori(pos.z)]
	ev.new_state = {
		"block_id": String(block_id),
		"position": [pos.x, pos.y, pos.z],
	}
	_event_bus.emit(ev)


func _schedule_save() -> void:
	if _save_pending:
		return
	_save_pending = true
	get_tree().create_timer(SAVE_DEBOUNCE_SEC).timeout.connect(_flush_save)


func _flush_save() -> void:
	_save_pending = false
	var state := snapshot_state()
	if state == null or state.is_empty():
		return
	if _persistence != null:
		_persistence.save_sandbox(state)
	if _event_bus != null:
		_event_bus.emit(DomainEvent.new("SandboxKitSaved", "system"))


## Synchronous flush used by dispose(): avoids the SceneTreeTimer race where
## the debounced callable would never fire after the bridge is queue_freed.
func _flush_save_sync() -> void:
	if not _save_pending:
		return
	_save_pending = false
	var state := snapshot_state()
	if state == null or state.is_empty():
		return
	if _persistence != null:
		_persistence.save_sandbox(state)
	if _event_bus != null:
		_event_bus.emit(DomainEvent.new("SandboxKitSaved", "system"))


func _on_player_joined(profile: SandboxPlayerProfile) -> void:
	_enforce_roster_cap()
	if _event_bus == null:
		return
	_event_bus.emit(DomainEvent.new(
		"SandboxKitPlayerJoined", "sandbox_player_%d" % profile.player_id))
	if _session_ref != null:
		_session_ref.add_player("sandbox_p%d" % profile.player_id)


func _on_player_left(profile: SandboxPlayerProfile) -> void:
	if _event_bus == null:
		return
	_event_bus.emit(DomainEvent.new(
		"SandboxKitPlayerLeft", "sandbox_player_%d" % profile.player_id))


func _on_saves_saved(path: String, count: int) -> void:
	if _event_bus == null:
		return
	var ev := DomainEvent.new("SandboxKitSaveWritten", "system")
	ev.payload = {"path": path, "block_count": count}
	_event_bus.emit(ev)


## --- helpers ----------------------------------------------------------------

## Kid-safety cap: leave excess players when the policy shrinks below the
## registry's own hard limit of MAX_PLAYERS.
func _enforce_roster_cap() -> void:
	var reg := PlayerRegistrySystem.instance
	if reg == null:
		return
	for profile in reg.profiles():
		if profile.player_id >= _max_players:
			reg.leave(profile.player_id)


func _reconnect(sig: Signal, cb: Callable) -> void:
	for conn in sig.get_connections():
		if conn.callable == cb:
			sig.disconnect(cb)
	sig.connect(cb)
