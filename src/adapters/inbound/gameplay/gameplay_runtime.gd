class_name GameplayRuntime
extends Node3D

signal session_ended
## Emitted when a rule's action fires.
##   action_kind: int — CompiledRule.ActionKind value
##   params:      Dict — action params
signal rule_fired(rule_id: String, action_kind: int, params: Dictionary)

var _world_renderer: WorldRenderer
var _player_controller: PlayerController
var _session: Session
var _audio_bus: AudioEventBus
var _sfx_player: SFXPlayer
var _effect_spawner: EffectSpawner
var _screen_feedback: ScreenFeedback
var _victory_sequence: VictorySequence
var _ambient_player: AudioStreamPlayer

# Rules engine — injected by main.gd via setup_rules() before start_session.
# Optional: GameplayRuntime keeps working with null rules (legacy worlds).
var _rules_runtime: RulesRuntimePort
var _rule_compiler: RuleCompilerService
var _score: int = 0
var _rules_active: bool = false

# Combat HUD references — built lazily in _build_hud.
var _hp_bar: ProgressBar
var _score_label: Label
var _enemy_root: Node3D
var _loot_root: Node3D
var _build_grid: BuildGrid
var _hotbar_panel: HBoxContainer
var _inventory_panel: VBoxContainer
var _inventory_labels: Dictionary = {}  ## item_id -> Label
var _weapon_tiers := [
	{"id": "fist",      "damage": 4,  "label": "Pięść",          "needs": {}},
	{"id": "stick",     "damage": 7,  "label": "Patyk",          "needs": {"wood_oak": 3}},
	{"id": "sword_iron","damage": 12, "label": "Żelazny miecz",  "needs": {"ore_iron": 3, "wood_oak": 2}},
	{"id": "sword_epic","damage": 20, "label": "Epicki miecz",   "needs": {"ore_iron": 8, "slime_gel": 5}},
]
var _current_weapon_index: int = 0
var _weapon_label: Label
var _wave_number: int = 0
var _wave_respawn_timer: float = 0.0
var _rng: RandomNumberGenerator = null
const WAVE_RESPAWN_DELAY := 6.0
## Kid falls below this y → soft-respawn. Fixes spring-launch
## softlock (Adv 2 H-5). Default world floor is y=0; -50 leaves a
## comfortable buffer for tall builds.
const FALL_KILL_PLANE_Y := -50.0

# Parental gates (Adv 2 TB-1, TB-2 fix). Default policy = combat off
# until parent toggles on. Without a policy injection, _spawn_starter_enemies
# + _spawn_next_wave become no-ops.
var _combat_policy: ParentalControlPolicy = null
var _audit_ledger: AuditLedgerPort = null
var _profile_id: String = ""

func _ready() -> void:
	_world_renderer = $WorldRenderer
	_player_controller = $PlayerController
	_audio_bus = $AudioEventBus
	_sfx_player = $SFXPlayer
	_effect_spawner = $EffectSpawner
	_screen_feedback = $ScreenFeedbackLayer/ScreenFeedback
	_victory_sequence = $VictorySequence
	_ambient_player = $AmbientPlayer

	# Ambient music is now driven by AudioBank (play_music called from PlayShell
	# when the world is chosen). The _ambient_player node is kept so the scene
	# tree is unchanged, but we no longer generate procedural noise here.
	# _ambient_player remains silent until AudioBank drives the music bus.

	if _player_controller != null:
		_player_controller.visible = false
		_player_controller.set_process_input(false)
		_player_controller.set_process(false)
		_player_controller.footstep.connect(_on_footstep)
		_player_controller.landed.connect(_on_landed)
		_player_controller.hard_landed.connect(_on_hard_landed)
		_player_controller.jumped.connect(_on_jumped)

	if _victory_sequence != null:
		_victory_sequence.setup(_effect_spawner, _audio_bus, _screen_feedback, _player_controller)
		_victory_sequence.completed.connect(_on_victory_completed)

## Inject the rules engine. Optional — if not called, rules are inactive
## and the runtime behaves like the legacy collect-or-touch-win path.
## Called by main.gd composition root before start_session.
func setup_rules(runtime: RulesRuntimePort, compiler: RuleCompilerService) -> void:
	_rules_runtime = runtime
	_rule_compiler = compiler
	if _rules_runtime != null and _rules_runtime.has_signal("rules_action"):
		if not _rules_runtime.is_connected("rules_action", _on_rules_action):
			_rules_runtime.connect("rules_action", _on_rules_action)


## Inject parental policy + audit ledger for combat. Adv 2 TB-1 + TB-2
## trust-fixes: combat now opt-in via ParentalControlPolicy.combat_enabled
## and every defeat / wave-spawn is forwarded to AuditLedger for the
## parent dashboard.
func setup_combat_governance(
	policy: ParentalControlPolicy,
	ledger: AuditLedgerPort,
	profile_id: String
) -> void:
	_combat_policy = policy
	_audit_ledger = ledger
	_profile_id = profile_id


func start_session(world: World, session: Session) -> void:
	_session = session
	_score = 0
	var t0 := Time.get_ticks_msec()
	print("[gameplay] start_session: world=%s nodes=%d rules=%d" %
		[world.world_id, world.scene_nodes.size(), world.game_rules.size()])
	_world_renderer.render_world(world)
	print("[gameplay] render_world done in %d ms" % (Time.get_ticks_msec() - t0))
	_register_world_rules(world)
	var spawn_pos := _world_renderer.get_spawn_position(0)
	_player_controller.spawn_at(spawn_pos + Vector3(0, 1, 0))
	_player_controller.visible = true
	_player_controller.set_process_input(true)
	_player_controller.set_process(true)
	# Don't capture mouse — kid needs to click ESC button / nav back if anything stalls.
	# Mouse capture made the apparent "hang" feel total since user couldn't escape.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Hide Main/Layout so the NavBar (top tabs) and other UI don't overlap the
	# HUD overlay added below. Gameplay is full-screen 3D + HUD only.
	# gameplay_runtime is rooted at scene-tree root so it stays visible.
	_set_main_layout_visible(false)
	print("[gameplay] session live in %d ms total" % (Time.get_ticks_msec() - t0))


## Hide / restore the InboundMain Layout (NavBar + Body) for fullscreen
## gameplay. Looks up the node by absolute path so we don't take a hard
## dependency on InboundMain from this Node3D.
func _set_main_layout_visible(value: bool) -> void:
	var layout := get_node_or_null("/root/Main/Layout")
	if layout != null:
		layout.visible = value

	# Spawn sparkle at player spawn
	if _effect_spawner != null:
		_effect_spawner.spawn_sparkle_burst(_player_controller.global_position)

	# Connect trigger areas
	for child in _world_renderer.get_children():
		if child is Area3D:
			if not child.body_entered.is_connected(_on_trigger_area_entered):
				child.body_entered.connect(_on_trigger_area_entered.bind(child))

	_build_hud()
	_spawn_starter_enemies()
	_setup_build_grid()


## Minecraft-lite voxel placement. Mounts a BuildGrid as a child of
## the gameplay runtime so blocks are siblings to enemies + world
## scenery. Player gets the grid reference for input handling.
## Seeds a handful of tree + ore_node blocks so the gear loop has
## producers (closes Adv 4 "wood_oak has no producer" finding).
func _setup_build_grid() -> void:
	if _build_grid != null and is_instance_valid(_build_grid):
		_build_grid.clear_all()
		_build_grid.queue_free()
	_build_grid = BuildGrid.new()
	_build_grid.name = "BuildGrid"
	add_child(_build_grid)
	if _player_controller != null and _player_controller.has_method("setup_build_grid"):
		_player_controller.setup_build_grid(_build_grid)
	_build_grid.block_placed.connect(_on_block_placed)
	_build_grid.block_removed.connect(_on_block_removed)
	_build_grid.block_dropped_item.connect(_on_block_dropped_item)
	_build_grid.block_place_failed.connect(_on_block_place_failed)
	_seed_resource_nodes()


## Spawn 6 tree_oak + 3 ore_node blocks around the player so mining
## actually produces wood_oak and ore_iron — without these the gear
## ladder is dead code. Positions randomized in 12-18m ring.
func _seed_resource_nodes() -> void:
	if _player_controller == null or _build_grid == null:
		return
	var spawn := _player_controller.global_position
	var rng := _ensure_rng()
	# Trees: cluster of 6 in two rings.
	for i in 6:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(10.0, 18.0)
		var pos := spawn + Vector3(cos(angle) * radius, 0.5, sin(angle) * radius)
		_build_grid.place_block(_build_grid.world_to_cell(pos), "tree_oak")
	# Iron ore: 3 nodes farther out so kid earns them.
	for i in 3:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(14.0, 22.0)
		var pos := spawn + Vector3(cos(angle) * radius, 0.5, sin(angle) * radius)
		_build_grid.place_block(_build_grid.world_to_cell(pos), "ore_node")


## True only when a non-null ParentalControlPolicy has combat_enabled.
## Defaults to false (no policy = no combat) per CLAUDE.md
## "consent → deny" rule.
func _is_combat_allowed() -> bool:
	if _combat_policy == null:
		return false
	return _combat_policy.combat_enabled


## 0 = waves disabled past the starter pack. Non-zero = hard cap on
## wave count. Driven by ParentalControlPolicy.combat_wave_cap.
func _wave_cap() -> int:
	if _combat_policy == null:
		return 0
	return _combat_policy.combat_wave_cap


## Append a combat-related audit record. Best-effort: silently
## drops if ledger is not wired (e.g. tests / autoplay before
## composition root finishes). Each record carries event_type
## prefixed with "combat_" so the parent dashboard can filter.
func _audit_combat(event_type: String, payload: Dictionary) -> void:
	if _audit_ledger == null:
		return
	var record_id := "%s_%d" % [event_type, Time.get_ticks_msec()]
	var record := AuditRecord.new(
		record_id,
		event_type,
		record_id,
		_profile_id,
		Time.get_datetime_string_from_system(true),
		payload,
		_audit_ledger.last_hash()
	)
	_audit_ledger.append_record(record)


func _ensure_rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng


## Mined block dropped an item. Add to inventory + show in HUD.
## Reuses _on_loot_picked_up path so gear auto-upgrade triggers.
func _on_block_dropped_item(drop_item_id: String, position: Vector3) -> void:
	if _audio_bus != null:
		_audio_bus.emit_sfx("collect", position)
	# Spawn a brief sparkle then add to inventory directly (mining is
	# tactile — no separate orb-grab step). Saves a tween + makes
	# break_block feel instant.
	if _effect_spawner != null:
		_effect_spawner.spawn_sparkle_burst(position)
	_on_loot_picked_up(drop_item_id, 1)


func _on_block_place_failed(reason: String) -> void:
	if _screen_feedback != null and reason == "capacity":
		_screen_feedback.flash(Color(1.0, 0.4, 0.4), 0.15)


func _on_block_placed(cell: Vector3i, kind_id: String) -> void:
	if _rules_runtime != null:
		_rules_runtime.set_context_value("blocks_placed", _build_grid.block_count())
		_rules_runtime.on_event("place_block", {"kind": kind_id, "cell": cell})


func _on_block_removed(cell: Vector3i, kind_id: String) -> void:
	if _rules_runtime != null:
		_rules_runtime.set_context_value("blocks_placed", _build_grid.block_count())
		_rules_runtime.on_event("break_block", {"kind": kind_id, "cell": cell})


## MVP: spawn a small kid-safe enemy pack around the player so the
## 7yo Roblox-fluent kid has someone to fight from the moment the
## world loads. Procedural — no Kenney character meshes needed.
## Three enemies: 2 green slimes + 1 pink bouncer at 8m / 12m / 14m
## from spawn.
##
## Gated by ParentalControlPolicy.combat_enabled (Adv 2 TB-1 fix).
## When combat is off, the runtime stays in the legacy
## collect-and-touch-win mode — no enemies, no waves.
func _spawn_starter_enemies() -> void:
	if _player_controller == null:
		return
	if not _is_combat_allowed():
		print("[combat] disabled by parental policy — no enemies spawned")
		return
	_audit_combat("combat_session_started", {
		"wave_cap": _wave_cap(),
		"profile_id": _profile_id,
	})
	if _enemy_root != null and is_instance_valid(_enemy_root):
		_enemy_root.queue_free()
	_enemy_root = Node3D.new()
	_enemy_root.name = "Enemies"
	add_child(_enemy_root)

	var spawn := _player_controller.global_position
	var def_a := EnemyDefinition.slime_green()
	var def_b := EnemyDefinition.slime_green()
	var def_c := EnemyDefinition.bouncer()

	_spawn_one(def_a, spawn + Vector3(8, 1, 0))
	_spawn_one(def_b, spawn + Vector3(-7, 1, 6))
	_spawn_one(def_c, spawn + Vector3(0, 1, 14))


func _spawn_one(def: EnemyDefinition, pos: Vector3) -> void:
	var enemy := EnemyController.new()
	enemy.add_to_group("enemies")
	# setup() before add_child so definition is non-null when _ready fires.
	enemy.setup(def, _player_controller)
	enemy.defeated.connect(_on_enemy_defeated)
	_enemy_root.add_child(enemy)
	enemy.global_position = pos


func _on_enemy_defeated(enemy_id: String, position: Vector3, loot: Array) -> void:
	print("[combat] defeated %s at %s loot=%s" % [enemy_id, position, loot])
	_audit_combat("combat_enemy_defeated", {
		"enemy_id": enemy_id,
		"wave_number": _wave_number,
		"loot_items": loot.size(),
		"profile_id": _profile_id,
	})
	if _audio_bus != null:
		_audio_bus.emit_sfx("collect", position)
	if _effect_spawner != null:
		_effect_spawner.spawn_sparkle_burst(position)
	if _rules_runtime != null:
		_rules_runtime.on_event("defeat_%s" % enemy_id, {"enemy_id": enemy_id})

	# Physical loot drops — spawn LootPickup orbs that the kid walks
	# into. Loot table entries may stack; we drop one pickup per
	# stack so the kid sees multiple orbs poof out.
	if _loot_root == null or not is_instance_valid(_loot_root):
		_loot_root = Node3D.new()
		_loot_root.name = "Loot"
		add_child(_loot_root)
	var index := 0
	for drop in loot:
		if not (drop is Dictionary):
			continue
		var item := String((drop as Dictionary).get("item_id", ""))
		var qty := int((drop as Dictionary).get("quantity", 0))
		if item == "" or qty <= 0:
			continue
		var angle := index * (TAU / 4.0)
		var offset := Vector3(cos(angle) * 0.8, 0.5, sin(angle) * 0.8)
		var pickup := LootPickup.new()
		pickup.setup(item, qty, _player_controller)
		pickup.picked_up.connect(_on_loot_picked_up)
		_loot_root.add_child(pickup)
		pickup.global_position = position + offset
		index += 1

	# Default scoring fallback (works even without compiled rules).
	_score += 5
	if _score_label != null:
		_score_label.text = "★ %d" % _score


func _on_loot_picked_up(item_id: String, quantity: int) -> void:
	if _audio_bus != null and _player_controller != null:
		_audio_bus.emit_sfx("collect", _player_controller.global_position)
	# Update inventory via rules-runtime context (single source of truth).
	if _rules_runtime != null:
		var inv: Variant = _rules_runtime.get_context_value("inventory")
		var inv_dict: Dictionary = inv if inv is Dictionary else {}
		inv_dict[item_id] = int(inv_dict.get(item_id, 0)) + quantity
		_rules_runtime.set_context_value("inventory", inv_dict)
		_rules_runtime.on_event("inventory_changed", {"item": item_id})
		_rules_runtime.on_event("collect_%s" % item_id, {})
		_refresh_inventory_panel(inv_dict)
		_try_auto_upgrade_weapon(inv_dict)
	else:
		# Fallback when rules runtime not wired — local inventory map.
		var inv_dict: Dictionary = {}
		inv_dict[item_id] = quantity
		_refresh_inventory_panel(inv_dict)


func _refresh_inventory_panel(inv: Dictionary) -> void:
	if _inventory_panel == null:
		return
	for item_id in inv.keys():
		var count := int(inv[item_id])
		var label: Label = _inventory_labels.get(item_id, null)
		if label == null:
			label = Label.new()
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
			label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
			label.add_theme_constant_override("shadow_offset_x", 2)
			label.add_theme_constant_override("shadow_offset_y", 2)
			_inventory_panel.add_child(label)
			_inventory_labels[item_id] = label
		label.text = "%s × %d" % [_pretty_item_name(item_id), count]


func _pretty_item_name(item_id: String) -> String:
	match item_id:
		"slime_gel": return "Galaretka"
		"coin": return "Moneta"
		"spring_coil": return "Sprężynka"
		"ore_iron": return "Żelazo"
		"wood_oak": return "Drewno"
		"star": return "Gwiazdka"
		_:
			return item_id.capitalize()


## Gear grinding loop: when kid has the materials, auto-upgrade weapon
## to the next tier and consume the inputs. Kid-friendly automation —
## no crafting menu UI for MVP, just a popup notification.
func _try_auto_upgrade_weapon(inv: Dictionary) -> void:
	if _current_weapon_index >= _weapon_tiers.size() - 1:
		return
	var next_tier: Dictionary = _weapon_tiers[_current_weapon_index + 1]
	var needs: Dictionary = next_tier.get("needs", {})
	for k in needs.keys():
		if int(inv.get(k, 0)) < int(needs[k]):
			return
	# Consume materials.
	for k in needs.keys():
		inv[k] = int(inv.get(k, 0)) - int(needs[k])
	if _rules_runtime != null:
		_rules_runtime.set_context_value("inventory", inv)
	_current_weapon_index += 1
	var tier: Dictionary = _weapon_tiers[_current_weapon_index]
	if _player_controller != null and _player_controller.has_method("equip_weapon_damage"):
		_player_controller.equip_weapon_damage(int(tier.get("damage", 4)))
	if _weapon_label != null:
		_weapon_label.text = "🗡 %s (%d dmg)" % [tier.get("label", ""), int(tier.get("damage", 4))]
	if _screen_feedback != null:
		_screen_feedback.flash(Color(1.0, 0.95, 0.4), 0.3)
	if _effect_spawner != null and _player_controller != null:
		_effect_spawner.spawn_sparkle_burst(_player_controller.global_position)
	print("[gear] upgraded to %s (%d dmg)" % [tier.get("label", ""), int(tier.get("damage", 4))])
	_refresh_inventory_panel(inv)


func _rebuild_hotbar_panel(active_slot: int) -> void:
	if _hotbar_panel == null:
		return
	for child in _hotbar_panel.get_children():
		child.queue_free()
	var catalog := BlockKind.default_catalog()
	for i in mini(catalog.size(), 5):
		var kind: BlockKind = catalog[i]
		var slot := ColorRect.new()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.color = kind.color
		# Active slot gets a bright outline via theme override on a wrapping
		# panel — cheap: just brighten the color.
		if i == active_slot:
			slot.color = kind.color.lightened(0.3)
		var label := Label.new()
		label.text = "%d" % (i + 1)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.position = Vector2(6, 4)
		slot.add_child(label)
		_hotbar_panel.add_child(slot)


func _on_hotbar_changed(active_slot: int, _block_id: String) -> void:
	_rebuild_hotbar_panel(active_slot)


func _on_player_hp_changed(current: int, max_hp: int) -> void:
	if _hp_bar == null:
		return
	_hp_bar.max_value = max_hp
	_hp_bar.value = current


func _on_player_defeated() -> void:
	# Kid-safe defeat — soft fade + respawn at spawn point, no game-over.
	print("[combat] player defeated — soft respawn")
	_audit_combat("combat_player_defeated", {
		"wave_number": _wave_number,
		"profile_id": _profile_id,
	})
	if _screen_feedback != null:
		_screen_feedback.flash(Color(1.0, 0.85, 0.85), 0.5)
	if _world_renderer != null and _player_controller != null:
		var spawn_pos := _world_renderer.get_spawn_position(0)
		_player_controller.spawn_at(spawn_pos + Vector3(0, 1, 0))
		if _player_controller.has_method("get_health"):
			var h: HealthState = _player_controller.get_health()
			if h != null:
				h.current_hp = h.max_hp
				h.is_alive = true
				_player_controller.hp_changed.emit(h.current_hp, h.max_hp)


## Kid-facing HUD: a Wróć button + control hint so a 5-7 year-old sees what to
## do after world load. Previously start_session hid PlayShell.Layout, left
## mouse captured, and gave no on-screen affordances — kid perceived a hang.
func _build_hud() -> void:
	if has_node("HUD"):
		return
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 5
	add_child(hud)

	var back := Button.new()
	back.name = "BackBtn"
	back.text = "← Wróć"
	back.custom_minimum_size = Vector2(160, 56)
	back.add_theme_font_size_override("font_size", 28)
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.offset_left = 32
	back.offset_top = 32
	back.offset_right = 192
	back.offset_bottom = 88
	back.pressed.connect(end_session)
	hud.add_child(back)

	# HP bar + score panel (top-right). 7yo combat HUD.
	var stats_panel := PanelContainer.new()
	stats_panel.name = "StatsPanel"
	stats_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stats_panel.offset_left = -240
	stats_panel.offset_top = 32
	stats_panel.offset_right = -32
	stats_panel.offset_bottom = 132
	hud.add_child(stats_panel)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 6)
	stats_panel.add_child(stats_vbox)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HpBar"
	_hp_bar.min_value = 0
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.custom_minimum_size = Vector2(180, 24)
	_hp_bar.add_theme_color_override("font_color", Color.WHITE)
	stats_vbox.add_child(_hp_bar)

	_score_label = Label.new()
	_score_label.name = "ScoreLabel"
	_score_label.text = "★ 0"
	_score_label.add_theme_font_size_override("font_size", 22)
	_score_label.add_theme_color_override("font_color", Color(1, 0.92, 0.4))
	_score_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_score_label.add_theme_constant_override("shadow_offset_x", 2)
	_score_label.add_theme_constant_override("shadow_offset_y", 2)
	stats_vbox.add_child(_score_label)

	_weapon_label = Label.new()
	_weapon_label.name = "WeaponLabel"
	_weapon_label.text = "🗡 Pięść (4 dmg)"
	_weapon_label.add_theme_font_size_override("font_size", 18)
	_weapon_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_weapon_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_weapon_label.add_theme_constant_override("shadow_offset_x", 2)
	_weapon_label.add_theme_constant_override("shadow_offset_y", 2)
	stats_vbox.add_child(_weapon_label)

	# Inventory panel — bottom-left, lists collected items + counts.
	_inventory_panel = VBoxContainer.new()
	_inventory_panel.name = "Inventory"
	_inventory_panel.add_theme_constant_override("separation", 4)
	_inventory_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_inventory_panel.offset_left = 32
	_inventory_panel.offset_top = -260
	_inventory_panel.offset_right = 240
	_inventory_panel.offset_bottom = -110
	hud.add_child(_inventory_panel)
	var inv_title := Label.new()
	inv_title.text = "🎒 Plecak"
	inv_title.add_theme_font_size_override("font_size", 20)
	inv_title.add_theme_color_override("font_color", Color.WHITE)
	inv_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	inv_title.add_theme_constant_override("shadow_offset_x", 2)
	inv_title.add_theme_constant_override("shadow_offset_y", 2)
	_inventory_panel.add_child(inv_title)

	# Wire HP signal from player.
	if _player_controller != null and _player_controller.has_signal("hp_changed"):
		_player_controller.hp_changed.connect(_on_player_hp_changed)
		_player_controller.player_defeated.connect(_on_player_defeated)

	# Crosshair (center) — 16×16 reticle so kid sees where their
	# raycast lands. Tiny + low-contrast so it doesn't overwhelm the
	# 3D scene. CenterContainer keeps it locked to viewport center
	# regardless of resize. (Adv 5 #2 fix.)
	var crosshair_layer := CenterContainer.new()
	crosshair_layer.name = "CrosshairContainer"
	crosshair_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(crosshair_layer)
	var crosshair := ColorRect.new()
	crosshair.name = "Crosshair"
	crosshair.custom_minimum_size = Vector2(16, 16)
	# White cross drawn via two thin ColorRects (cheap; no PNG asset
	# needed for MVP). 2px thick, 16px wide.
	crosshair.color = Color(1, 1, 1, 0.0)  ## transparent root
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crosshair_h := ColorRect.new()
	crosshair_h.color = Color(1, 1, 1, 0.8)
	crosshair_h.position = Vector2(0, 7)
	crosshair_h.size = Vector2(16, 2)
	crosshair_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_child(crosshair_h)
	var crosshair_v := ColorRect.new()
	crosshair_v.color = Color(1, 1, 1, 0.8)
	crosshair_v.position = Vector2(7, 0)
	crosshair_v.size = Vector2(2, 16)
	crosshair_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_child(crosshair_v)
	crosshair_layer.add_child(crosshair)

	# Hotbar (bottom-center) — 5 block-kind slots, kid hits 1..5 to switch.
	_hotbar_panel = HBoxContainer.new()
	_hotbar_panel.name = "Hotbar"
	_hotbar_panel.add_theme_constant_override("separation", 8)
	_hotbar_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar_panel.offset_left = -280
	_hotbar_panel.offset_top = -96
	_hotbar_panel.offset_right = 280
	_hotbar_panel.offset_bottom = -24
	hud.add_child(_hotbar_panel)
	_rebuild_hotbar_panel(0)
	if _player_controller != null and _player_controller.has_signal("hotbar_changed"):
		_player_controller.hotbar_changed.connect(_on_hotbar_changed)

	var hint := Label.new()
	hint.name = "ControlsHint"
	hint.text = "WSAD ruch  •  SPACJA skok  •  LPM atak  •  K stawiaj  •  L niszcz  •  1-5 wybór  •  PPM obrót  •  ESC"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	hint.add_theme_constant_override("shadow_offset_x", 2)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.offset_left = -360
	hint.offset_top = 36
	hint.offset_right = 360
	hint.offset_bottom = 76
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(hint)

func _physics_process(delta: float) -> void:
	if _rules_active and _rules_runtime != null:
		_rules_runtime.tick(delta)
	_check_enemy_wave_respawn(delta)
	_check_fall_kill_plane()


## Spring block can launch kid past the world edge (Adv 2 H-5). If
## player y drops below FALL_KILL_PLANE_Y, trigger soft-respawn —
## same flow as HP=0. No game-over screen, no death — just a soft
## fade-flash + teleport back to spawn point.
func _check_fall_kill_plane() -> void:
	if _player_controller == null or not is_instance_valid(_player_controller):
		return
	if _player_controller.global_position.y < FALL_KILL_PLANE_Y:
		_on_player_defeated()


## Endless engagement: once kid clears all enemies in a wave, after
## WAVE_RESPAWN_DELAY seconds spawn the next wave with +1 enemy and
## a stronger archetype mix. Drives the gear-grinding loop.
func _check_enemy_wave_respawn(delta: float) -> void:
	if _enemy_root == null or not is_instance_valid(_enemy_root):
		return
	if _player_controller == null or not is_instance_valid(_player_controller):
		return
	# Are there any live enemies?
	for child in _enemy_root.get_children():
		if child is EnemyController and (child as EnemyController).health.is_alive:
			_wave_respawn_timer = 0.0
			return
	_wave_respawn_timer += delta
	if _wave_respawn_timer >= WAVE_RESPAWN_DELAY:
		_wave_respawn_timer = 0.0
		_spawn_next_wave()


func _spawn_next_wave() -> void:
	if _player_controller == null or not is_instance_valid(_player_controller):
		return
	if not _is_combat_allowed():
		return
	# Honor parental wave cap (Adv 2 H-3 difficulty-cliff fix). 0 = no
	# extra waves past the starter pack. Non-zero caps wave count.
	var cap := _wave_cap()
	if cap > 0 and _wave_number >= cap:
		print("[combat] wave cap %d reached — no further spawn" % cap)
		return
	_wave_number += 1
	print("[combat] wave %d spawning" % _wave_number)
	_audit_combat("combat_wave_started", {
		"wave_number": _wave_number,
		"profile_id": _profile_id,
	})
	var pack_size := mini(3 + _wave_number, 7)
	var spawn := _player_controller.global_position
	var rng := _ensure_rng()
	for i in pack_size:
		var roll := rng.randf()
		var def: EnemyDefinition
		if _wave_number >= 3 and roll < 0.4:
			def = EnemyDefinition.slime_blue()
		elif roll < 0.7:
			def = EnemyDefinition.slime_green()
		else:
			def = EnemyDefinition.bouncer()
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(8.0, 14.0)
		var pos := spawn + Vector3(cos(angle) * radius, 1.0, sin(angle) * radius)
		_spawn_one(def, pos)
	if _screen_feedback != null:
		_screen_feedback.flash(Color(1.0, 0.4, 0.4), 0.25)


func _register_world_rules(world: World) -> void:
	_rules_active = false
	if _rules_runtime == null or _rule_compiler == null:
		return
	if world == null or world.game_rules.is_empty():
		_rules_runtime.reset()
		return
	var compiled := _rule_compiler.compile_all(world.game_rules)
	if compiled.is_empty():
		_rules_runtime.reset()
		return
	_rules_runtime.reset()
	_rules_runtime.register_rules(compiled)
	_rules_runtime.set_context_value("score", 0)
	_rules_runtime.set_context_value("inventory", {})
	_rules_active = true
	print("[gameplay] rules engine active — %d compiled rules" % compiled.size())


## Dispatch table for fired rule actions. Mirrors CompiledRule.ActionKind.
func _on_rules_action(rule_id: String, action_kind: int, params: Dictionary) -> void:
	# Mirror in the rule_fired signal so external listeners (HUD, telemetry)
	# can react without coupling to the runtime port directly.
	emit_signal("rule_fired", rule_id, action_kind, params)
	# Match on named enum values (not int literals) — survives enum
	# reordering. Adv 6 #4 fix.
	match action_kind:
		CompiledRule.ActionKind.ADD_SCORE:
			var amount := int(params.get("amount", 0))
			_score += amount
			if _rules_runtime != null:
				_rules_runtime.set_context_value("score", _score)
			print("[gameplay] add_score(%d) -> %d (rule=%s)" % [amount, _score, rule_id])
		CompiledRule.ActionKind.SPAWN_ITEM:
			print("[gameplay] spawn_item(%s, %d) — not yet implemented" %
				[String(params.get("item", "")), int(params.get("count", 0))])
		CompiledRule.ActionKind.WIN_LEVEL:
			print("[gameplay] win_level fired (rule=%s)" % rule_id)
			_trigger_victory()
		CompiledRule.ActionKind.UNLOCK_AREA:
			print("[gameplay] unlock_area(%s) — deferred to BUILDER wave" %
				String(params.get("zone_id", "")))
		CompiledRule.ActionKind.OPEN_GATE:
			print("[gameplay] open_gate — deferred")
		CompiledRule.ActionKind.SET_RESPAWN_POINT:
			if _player_controller != null and is_instance_valid(_player_controller):
				_player_controller.set_meta("respawn_point",
					_player_controller.global_position)
		CompiledRule.ActionKind.CUSTOM_CALLBACK:
			print("[gameplay] custom_callback(%s) — deferred" %
				String(params.get("callback_name", "")))
		_:
			push_warning("Unknown action_kind: %d" % action_kind)


func end_session() -> void:
	_rules_active = false
	if _rules_runtime != null:
		_rules_runtime.reset()
	if _build_grid != null and is_instance_valid(_build_grid):
		_build_grid.clear_all()
	if _enemy_root != null and is_instance_valid(_enemy_root):
		for e in _enemy_root.get_children():
			if e is EnemyController:
				e.queue_free()
	if _loot_root != null and is_instance_valid(_loot_root):
		for l in _loot_root.get_children():
			if l is LootPickup:
				l.queue_free()
	_inventory_labels.clear()
	_current_weapon_index = 0
	_wave_number = 0
	_wave_respawn_timer = 0.0
	_world_renderer.clear_world()
	if _player_controller != null:
		_player_controller.visible = false
		_player_controller.set_process_input(false)
		_player_controller.set_process(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Restore Main/Layout (NavBar + Body) so the kid sees Landing on return.
	_set_main_layout_visible(true)
	session_ended.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		end_session()

func _on_footstep() -> void:
	if _audio_bus != null:
		_audio_bus.emit_sfx("step", _player_controller.global_position)

func _on_landed() -> void:
	if _audio_bus != null:
		_audio_bus.emit_sfx("land", _player_controller.global_position)
	if _effect_spawner != null:
		var feet_pos := _player_controller.global_position - Vector3(0, _player_controller.scale.y * 0.9, 0)
		_effect_spawner.spawn_dust_puff(feet_pos)

func _on_jumped() -> void:
	if _audio_bus != null:
		_audio_bus.emit_sfx("jump", _player_controller.global_position)

func _on_hard_landed() -> void:
	if _screen_feedback != null:
		_screen_feedback.shake(4.0, 0.2)

func _on_trigger_area_entered(body: Node3D, area: Area3D) -> void:
	if body != _player_controller:
		return
	var trigger_type: String = area.get_meta("trigger_type", "collectible")
	# Forward zone-enter to rules runtime so on_<event> triggers can fire.
	if _rules_active and _rules_runtime != null:
		_rules_runtime.on_event("zone_%s" % trigger_type, {"zone_id": area.name})
		_rules_runtime.on_event("reach_%s" % trigger_type, {"zone_id": area.name})
	match trigger_type:
		"win":
			_trigger_victory()
		"collectible", _:
			_trigger_collectible(area)

func _trigger_collectible(area: Area3D) -> void:
	if _audio_bus != null:
		_audio_bus.emit_sfx("collect", area.global_position)
	if _effect_spawner != null:
		_effect_spawner.spawn_collect_effect(area.global_position)
	if _screen_feedback != null:
		_screen_feedback.flash(Color(1.0, 1.0, 1.0), 0.15)
	# Disable the trigger so it can only be collected once
	area.set_deferred("monitoring", false)
	area.visible = false
	# Forward to rules runtime — increment inventory + fire ON_COLLECT_COUNT.
	if _rules_active and _rules_runtime != null:
		var item_name: String = area.get_meta("item_name", area.name)
		var inv: Dictionary = _rules_runtime.get_context_value("inventory")
		if inv == null:
			inv = {}
		inv[item_name] = int(inv.get(item_name, 0)) + 1
		_rules_runtime.set_context_value("inventory", inv)
		_rules_runtime.on_event("inventory_changed", {"item": item_name})
		_rules_runtime.on_event("collect_%s" % item_name, {})

func _trigger_victory() -> void:
	if _victory_sequence != null:
		_victory_sequence.play()

func _on_victory_completed() -> void:
	end_session()
