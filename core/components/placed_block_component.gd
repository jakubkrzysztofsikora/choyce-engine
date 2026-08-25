class_name PlacedBlockComponent
extends SandboxComponent
## Runtime identity of a block that has been placed in the world.
## This is the hook the chunk hot/cold baker reads, and the thing SaveSystem
## serialises. It carries NO node references — only plain data — precisely so
## the block can be freed and rebuilt from this record.

@export var block_id: StringName = &""
@export var placed_by_player: int = -1
@export var chunk_coord: Vector3i = Vector3i.ZERO
@export var tint: Color = Color.WHITE


func _component_key() -> StringName:
	return Components.PLACED_BLOCK


## Plain-data record. Deliberately primitives only: this must be safe to write
## with FileAccess.store_var and safe to read back from an untrusted file.
func to_record() -> Dictionary:
	var t: Transform3D = (entity as Node3D).global_transform
	return {
		"id": String(block_id),
		"by": placed_by_player,
		"pos": t.origin,
		"rot": t.basis.get_euler(),
		"tint": tint,
	}


## Parameter is deliberately UNTYPED. With `rec: Dictionary` the typeof() guard
## below is unreachable — GDScript enforces the declared type at call time, so a
## save whose "blocks" array contains ints or strings raised a runtime type
## error per element instead of being cleanly rejected.
static func from_record(rec) -> Dictionary:
	## Validates and normalises one record read from disk. Returns {} if the
	## record is malformed. Treat every save as hostile input — players share
	## creations, and the moment they do somebody crafts a bad one.
	if typeof(rec) != TYPE_DICTIONARY:
		return {}
	if not (rec.has("id") and rec.has("pos") and rec.has("rot")):
		return {}
	if typeof(rec["id"]) != TYPE_STRING:
		return {}
	# Bound the id BEFORE it is interned as a StringName. Strings decode bounded
	# only by remaining buffer, so a 30 MB id in a 32 MB file is legal, and
	# StringName construction hashes and interns the whole thing.
	if (rec["id"] as String).length() > 64 or (rec["id"] as String).is_empty():
		return {}
	if typeof(rec["pos"]) != TYPE_VECTOR3 or typeof(rec["rot"]) != TYPE_VECTOR3:
		return {}

	var pos: Vector3 = rec["pos"]
	var rot: Vector3 = rec["rot"]
	if not (is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z)):
		return {}
	if not (is_finite(rot.x) and is_finite(rot.y) and is_finite(rot.z)):
		return {}

	# Clamp to the play area, not to 1e5. CHUNK_SIZE is 32, so +/-100000 permits
	# ~10^11 distinct chunk coords, and _update_chunk_states scans every live
	# chunk every physics tick at 120 Hz.
	const LIMIT := 2048.0
	pos = pos.clamp(Vector3.ONE * -LIMIT, Vector3.ONE * LIMIT)

	# Wrap rotation into [0, TAU). Huge-but-finite eulers (1e30) do not crash
	# Basis.from_euler, but libm argument reduction differs across platforms, so
	# the same shared save renders a different world on a different machine.
	rot = Vector3(fposmod(rot.x, TAU), fposmod(rot.y, TAU), fposmod(rot.z, TAU))

	# Clamp tint. Color components are unbounded floats: Color(1e30, 1e30, 1e30)
	# fed to MultiMesh.set_instance_color with glow enabled is a full-screen
	# white flash across ALL FOUR panes from one shared save file. NaN is worse
	# and driver-dependent.
	var tint := Color.WHITE
	if rec.has("tint") and typeof(rec["tint"]) == TYPE_COLOR:
		var c: Color = rec["tint"]
		if is_finite(c.r) and is_finite(c.g) and is_finite(c.b) and is_finite(c.a):
			tint = Color(clampf(c.r, 0.0, 1.0), clampf(c.g, 0.0, 1.0),
				clampf(c.b, 0.0, 1.0), clampf(c.a, 0.0, 1.0))

	# Reject rather than clamp, and derive the bound from the real constant.
	# clampi(..., -1, 3) silently collapsed players 4+ onto player 3 the moment
	# MAX_PLAYERS changed.
	var by := -1
	if rec.has("by") and typeof(rec["by"]) == TYPE_INT:
		var raw_by: int = rec["by"]
		if raw_by < -1 or raw_by >= PlayerRegistrySystem.MAX_PLAYERS:
			return {}
		by = raw_by

	return {"id": rec["id"], "by": by, "pos": pos, "rot": rot, "tint": tint}
