## Smoke tests for LootTableData.generate — chance gate, quantity range, determinism.
## Run: godot --headless --script tests/domain/test_loot_table_data.gd
class_name TestLootTableData
extends SceneTree


func _init() -> void:
	var failures: Array = []

	# empty entries → []
	var empty := LootTableData.new()
	var rng := _seeded_rng(42)
	var out_empty: Array = empty.generate(rng)
	if not out_empty.is_empty():
		failures.append("empty_table_returns_empty: got=%s" % str(out_empty))

	# single entry chance=1.0, min=max=1 → always {item_id, quantity:1}
	var always := LootTableData.new()
	always.entries = [_mk_entry("gem", 1, 1, 1.0)]
	for i in range(20):
		var drops: Array = always.generate(_seeded_rng(i))
		if drops.size() != 1:
			failures.append("always_table_size i=%d got=%d" % [i, drops.size()])
			break
		if int(drops[0]["quantity"]) != 1 or String(drops[0]["item_id"]) != "gem":
			failures.append("always_table_payload i=%d got=%s" % [i, str(drops[0])])
			break

	# chance=0.0 → never appears
	var never := LootTableData.new()
	never.entries = [_mk_entry("dust", 1, 1, 0.0)]
	for i in range(50):
		var d2: Array = never.generate(_seeded_rng(i + 100))
		if not d2.is_empty():
			failures.append("never_table_should_be_empty i=%d got=%s" % [i, str(d2)])
			break

	# chance=1.0, min=2 max=4 → quantity in [2,4]
	var ranged := LootTableData.new()
	ranged.entries = [_mk_entry("coin", 2, 4, 1.0)]
	for i in range(30):
		var d3: Array = ranged.generate(_seeded_rng(i + 500))
		if d3.size() != 1:
			failures.append("ranged_drop_size i=%d got=%d" % [i, d3.size()])
			break
		var q := int(d3[0]["quantity"])
		if q < 2 or q > 4:
			failures.append("ranged_qty_oob i=%d q=%d" % [i, q])
			break

	# determinism: same seed → identical drops
	var det := LootTableData.new()
	det.entries = [
		_mk_entry("a", 1, 5, 0.5),
		_mk_entry("b", 2, 8, 0.7),
		_mk_entry("c", 1, 3, 1.0),
	]
	var run_a: Array = det.generate(_seeded_rng(1234))
	var run_b: Array = det.generate(_seeded_rng(1234))
	if str(run_a) != str(run_b):
		failures.append("determinism: a=%s b=%s" % [str(run_a), str(run_b)])

	if failures.is_empty():
		print("[test_loot_table_data] OK")
		quit(0)
	else:
		printerr("[test_loot_table_data] FAIL ", failures.size())
		for f in failures:
			printerr("  - ", f)
		quit(1)


func _mk_entry(item_id: String, min_qty: int, max_qty: int, chance: float) -> LootEntry:
	var e := LootEntry.new()
	e.item_id = item_id
	e.min_qty = min_qty
	e.max_qty = max_qty
	e.chance = chance
	return e


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r
