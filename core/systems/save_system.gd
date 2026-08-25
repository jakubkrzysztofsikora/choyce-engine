class_name SaveSystem
extends Node
## Autoload "Saves". Reach via SaveSystem.instance.
##
## SECURITY, and this is not optional:
## Godot's `load()` on a .tres/.res/.tscn will EXECUTE embedded GDScript. That
## is an acknowledged, still-open engine gap (godot-proposals #10968, #4925).
## Player creations get shared. The moment they do, somebody crafts a malicious
## one. Therefore:
##
##   - saves are PLAIN DATA ONLY, written with FileAccess.store_var(full=false)
##   - `full_objects` is false so no Object can be encoded or decoded at all
##   - every record is re-validated on load, clamped, and unknown ids dropped
##   - block ids are STRINGS, never palette indices
##
## Never replace this with ResourceSaver/ResourceLoader for player content.

static var instance: SaveSystem

const SCHEMA_VERSION := 1
const MAGIC := "SBXSAVE"
const SAVE_DIR := "user://creations"
const MAX_BLOCKS := 200000
## Hard byte cap checked BEFORE FileAccess.get_var touches the file.
## A legitimate 200k-block save is ~24 MB.
const MAX_FILE_BYTES := 33554432   # 32 MiB
## Blocks from a loaded file are charged to THIS player's budget, not to the
## per-record "by" field. "by" is attacker-controlled: a crafted save tagging
## 2000 blocks each to players 0/1/2 pins all three at max_blocks_per_player
## and locks them out of building for the rest of the session.
var load_credit_player: int = -1

signal saved(path: String, count: int)
signal loaded(path: String, count: int, rejected: int)

var last_rejected: int = 0


func _ready() -> void:
	instance = self
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func save_path(slot: String) -> String:
	return "%s/%s.sbx" % [SAVE_DIR, slot.validate_filename()]


func save(slot: String) -> bool:
	var build := BuildSystem.instance
	if build == null:
		return false

	var records := build.all_records()
	var payload := {
		"magic": MAGIC,
		"version": SCHEMA_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"blocks": records,
	}

	var f := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: cannot open %s for write (%d)"
			% [save_path(slot), FileAccess.get_open_error()])
		return false
	# full_objects = false. This is the line that makes the format safe.
	f.store_var(payload, false)
	f.close()
	saved.emit(save_path(slot), records.size())
	return true


func load_into_world(slot: String) -> bool:
	var build := BuildSystem.instance
	if build == null:
		return false

	var path := save_path(slot)
	if not FileAccess.file_exists(path):
		return false

	# SIZE CAP BEFORE get_var. FileAccess.get_var reads a raw uint32 length
	# prefix and reserves that many bytes BEFORE parsing or validating anything,
	# so a 9-byte file whose first four bytes are FF FF FF FF requests a 4 GiB
	# allocation. MAX_BLOCKS is checked far too late to help.
	var size_probe := FileAccess.open(path, FileAccess.READ)
	if size_probe == null:
		return false
	var byte_size := size_probe.get_length()
	size_probe.close()
	if byte_size > MAX_FILE_BYTES:
		push_error("SaveSystem: %s is %d bytes (cap %d), refusing" % [path, byte_size, MAX_FILE_BYTES])
		return false

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	# full_objects = false blocks class instantiation and the "script" property
	# path — the actual RCE vector. NOTE: it does NOT block every Variant of
	# type OBJECT (EncodedObjectAsID, Signal, RID and NodePath still decode), so
	# no save field may ever be a NodePath or a path String.
	var raw = f.get_var(false)
	f.close()

	var payload := _validate_envelope(raw)
	if payload.is_empty():
		push_error("SaveSystem: %s failed envelope validation, refusing to load" % path)
		return false

	# PHASE 1 — validate and stage everything. clear_all() used to run BEFORE
	# any record was checked, so a file that passed the four shallow envelope
	# checks and contained nothing but garbage wiped the players' live world and
	# then reported success.
	var staged: Array = []
	var rejected := 0
	for entry in payload["blocks"]:
		var rec := PlacedBlockComponent.from_record(entry)
		if rec.is_empty():
			rejected += 1
			continue
		var id := StringName(rec["id"])
		if not build.knows(id):
			rejected += 1     # unknown block: drop it, never guess a substitute
			continue
		staged.append({
			"id": String(id),
			"by": rec["by"],
			"pos": rec["pos"],
			"rot": rec["rot"],
			"tint": rec["tint"],
		})

	last_rejected = rejected
	if staged.is_empty():
		push_error("SaveSystem: %s produced 0 usable records (%d rejected) — world untouched"
			% [path, rejected])
		return false

	# PHASE 2 — commit. Bulk path, one cold bake per chunk. Calling place() in a
	# loop here is O(n^2) in node allocations and OOMs on a ~1 MB file.
	build.clear_all()
	var accepted: int = build.place_bulk(staged, load_credit_player)
	loaded.emit(path, accepted, rejected)
	return true


func _validate_envelope(raw) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = raw
	if d.get("magic", "") != MAGIC:
		return {}
	var v = d.get("version", -1)
	if typeof(v) != TYPE_INT:
		return {}
	# LOWER BOUND MATTERS. Without it, version: -9223372036854775808 passes the
	# "newer than us" check and drops into _migrate's stepping loop — a
	# quintillion-iteration hang from a 40-byte file.
	if v < 1 or v > SCHEMA_VERSION:
		push_error("SaveSystem: unsupported schema v%s (this build is v%d)"
			% [str(v), SCHEMA_VERSION])
		return {}
	if v < SCHEMA_VERSION:
		d = _migrate(d, v)
	var blocks = d.get("blocks", null)
	if typeof(blocks) != TYPE_ARRAY:
		return {}
	if blocks.size() > MAX_BLOCKS:
		push_error("SaveSystem: %d blocks exceeds the %d cap, refusing"
			% [blocks.size(), MAX_BLOCKS])
		return {}
	return d


## Migration chain. Written on day one deliberately: sandbox saves outlive the
## code that made them, and retrofitting migrations is how communities lose
## their builds.
func _migrate(d: Dictionary, from_version: int) -> Dictionary:
	var v := from_version
	while v < SCHEMA_VERSION:
		match v:
			0:
				# v0 -> v1: pre-tint saves. Nothing to do, defaults apply.
				pass
			_:
				push_warning("SaveSystem: no migration from v%d" % v)
		v += 1
	d["version"] = SCHEMA_VERSION
	return d


func list_slots() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".sbx"):
			out.append(f.trim_suffix(".sbx"))
	return out


func delete_slot(slot: String) -> bool:
	var path := save_path(slot)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
