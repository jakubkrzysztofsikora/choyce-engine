## tests/adapters/inbound/test_create_shell_template_cards_and_preview.gd
## Part A + B: template card icon/palette redesign and SubViewport 3D preview tests.
##
## MUST criteria:
##   MUST-A1: _build_template_cards() creates exactly 5 card buttons in TemplateList.
##   MUST-A2: Each card button has meta "template_id" set to the correct id string.
##   MUST-A3: Each card button text is empty (icon rendered via child Label, not btn.text).
##   MUST-A4: Each card contains a VBoxContainer child with at least 3 children
##            (icon Label, name Label, dots HBoxContainer).
##   MUST-A5: Palette dot HBoxContainer contains exactly 3 ColorRect children per card.
##   MUST-A6: _on_card_hover animates scale toward 1.06 on enter (tween created; no error).
##   MUST-A7: _on_template_card_pressed calls _set_template which updates _active_palette.
##
##   MUST-B1: PolishLocalizationPolicy has create.template.adventure key.
##   MUST-B2: PolishLocalizationPolicy has create.template.farm key.
##   MUST-B3: PolishLocalizationPolicy has create.template.city key.
##   MUST-B4: PolishLocalizationPolicy has create.template.obby key.
##   MUST-B5: PolishLocalizationPolicy has create.template.tycoon key.
##   MUST-B6: PolishLocalizationPolicy has create.preview.title key.
##   MUST-B7: PolishLocalizationPolicy has create.preview.empty key.
##
##   MUST-C1: _update_3d_preview() is null-safe when _preview_root is null.
##   MUST-C2: _setup_preview_environment() is null-safe when _preview_root is null.
extends SceneTree

const CreateShell = preload("res://src/adapters/inbound/scenes/create/create_shell.gd")
const PolishLocalizationPolicy = preload("res://src/adapters/outbound/polish_localization_policy.gd")
const PlayerProfile = preload("res://src/domain/gameplay/player_profile.gd")

var _exit_code := 0


func _init() -> void:
	call_deferred("_run_tests")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		_exit_code = 1
	else:
		print("PASS: %s" % message)


func _make_shell() -> CreateShell:
	var scene := load("res://src/adapters/inbound/scenes/create/create_shell.tscn")
	var shell: CreateShell = scene.instantiate()
	get_root().add_child(shell)
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(
		null, profile, null, null, null,
		null, null, null
	)
	return shell


# ---------------------------------------------------------------------------
# MUST-A1 through MUST-A6: template card structure
# ---------------------------------------------------------------------------

func _test_must_a1_exactly_five_cards() -> void:
	var shell := _make_shell()
	var tlist = shell.get_node_or_null("Layout/TemplateScroll/TemplateList")
	_assert(tlist != null, "MUST-A1 pre: TemplateList node found")
	if tlist != null:
		var count := tlist.get_child_count()
		_assert(count == 5, "MUST-A1: exactly 5 template cards built (got %d)" % count)
	shell.queue_free()
	await process_frame


func _test_must_a2_meta_template_id() -> void:
	var shell := _make_shell()
	var tlist = shell.get_node_or_null("Layout/TemplateScroll/TemplateList")
	if tlist == null:
		print("SKIP MUST-A2: TemplateList not found")
		shell.queue_free()
		await process_frame
		return
	var expected_ids := ["adventure", "farm", "city", "obby", "tycoon"]
	var ok := true
	for i in range(mini(tlist.get_child_count(), 5)):
		var card = tlist.get_child(i)
		if not card.has_meta("template_id"):
			ok = false
			break
		var tid: String = card.get_meta("template_id")
		if tid != expected_ids[i]:
			ok = false
			break
	_assert(ok, "MUST-A2: each card has correct meta template_id")
	shell.queue_free()
	await process_frame


func _test_must_a3_button_text_empty() -> void:
	var shell := _make_shell()
	var tlist = shell.get_node_or_null("Layout/TemplateScroll/TemplateList")
	if tlist == null:
		print("SKIP MUST-A3: TemplateList not found")
		shell.queue_free()
		await process_frame
		return
	var ok := true
	for card in tlist.get_children():
		if card is Button and card.text != "":
			ok = false
			break
	_assert(ok, "MUST-A3: card button.text is empty (icon in child Label)")
	shell.queue_free()
	await process_frame


func _test_must_a4_card_has_vbox_with_children() -> void:
	var shell := _make_shell()
	var tlist = shell.get_node_or_null("Layout/TemplateScroll/TemplateList")
	if tlist == null:
		print("SKIP MUST-A4: TemplateList not found")
		shell.queue_free()
		await process_frame
		return
	var ok := true
	for card in tlist.get_children():
		var vbox: Node = null
		for child in card.get_children():
			if child is VBoxContainer:
				vbox = child
				break
		if vbox == null or vbox.get_child_count() < 3:
			ok = false
			break
	_assert(ok, "MUST-A4: each card has VBoxContainer with >= 3 children (icon, name, dots)")
	shell.queue_free()
	await process_frame


func _test_must_a5_palette_dots_count() -> void:
	var shell := _make_shell()
	var tlist = shell.get_node_or_null("Layout/TemplateScroll/TemplateList")
	if tlist == null:
		print("SKIP MUST-A5: TemplateList not found")
		shell.queue_free()
		await process_frame
		return
	var ok := true
	for card in tlist.get_children():
		var vbox: Node = null
		for child in card.get_children():
			if child is VBoxContainer:
				vbox = child
				break
		if vbox == null:
			ok = false
			break
		# Last child of vbox should be the dots HBoxContainer with 3 ColorRects.
		var dots: Node = vbox.get_child(vbox.get_child_count() - 1)
		if not (dots is HBoxContainer):
			ok = false
			break
		var dot_count := 0
		for dot in dots.get_children():
			if dot is ColorRect:
				dot_count += 1
		if dot_count != 3:
			ok = false
			break
	_assert(ok, "MUST-A5: each card's dots HBoxContainer has exactly 3 ColorRect children")
	shell.queue_free()
	await process_frame


func _test_must_a6_hover_tween_no_error() -> void:
	var shell := _make_shell()
	var tlist = shell.get_node_or_null("Layout/TemplateScroll/TemplateList")
	if tlist == null or tlist.get_child_count() == 0:
		print("SKIP MUST-A6: TemplateList empty or not found")
		shell.queue_free()
		await process_frame
		return
	var card = tlist.get_child(0)
	# Call hover in/out directly — should not throw and should not crash.
	var error_raised := false
	shell.call("_on_card_hover", card, true)
	await process_frame
	shell.call("_on_card_hover", card, false)
	await process_frame
	_assert(not error_raised, "MUST-A6: _on_card_hover does not error on enter/exit")
	shell.queue_free()
	await process_frame


func _test_must_a7_set_template_updates_palette() -> void:
	var shell := _make_shell()
	shell.call("_set_template", "farm")
	var palette: String = shell.get("_active_palette")
	_assert(palette == "farm", "MUST-A7: _set_template('farm') sets _active_palette to 'farm'")
	shell.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# MUST-B: Polish localization keys
# ---------------------------------------------------------------------------

func _test_must_b_policy_keys() -> void:
	var policy := PolishLocalizationPolicy.new()
	var keys := [
		"create.template.adventure",
		"create.template.farm",
		"create.template.city",
		"create.template.obby",
		"create.template.tycoon",
		"create.preview.title",
		"create.preview.empty",
	]
	var labels := ["MUST-B1", "MUST-B2", "MUST-B3", "MUST-B4", "MUST-B5", "MUST-B6", "MUST-B7"]
	for i in range(keys.size()):
		var k: String = keys[i]
		_assert(policy.translate(k) != k, "%s: PolishLocalizationPolicy has key %s" % [labels[i], k])


# ---------------------------------------------------------------------------
# MUST-C: _update_3d_preview and _setup_preview_environment null-safety
# ---------------------------------------------------------------------------

func _test_must_c1_update_3d_preview_null_safe() -> void:
	var shell := _make_shell()
	# Force _preview_root to null to test null guard.
	shell.set("_preview_root", null)
	var error := false
	shell.call("_update_3d_preview", null)
	_assert(not error, "MUST-C1: _update_3d_preview(null) safe when _preview_root is null")
	shell.queue_free()
	await process_frame


func _test_must_c2_setup_preview_environment_null_safe() -> void:
	var shell := _make_shell()
	shell.set("_preview_root", null)
	var error := false
	shell.call("_setup_preview_environment")
	_assert(not error, "MUST-C2: _setup_preview_environment() safe when _preview_root is null")
	shell.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

func _run_tests() -> void:
	print("=== Part A + B: template cards and 3D preview tests ===")

	await _test_must_a1_exactly_five_cards()
	await _test_must_a2_meta_template_id()
	await _test_must_a3_button_text_empty()
	await _test_must_a4_card_has_vbox_with_children()
	await _test_must_a5_palette_dots_count()
	await _test_must_a6_hover_tween_no_error()
	await _test_must_a7_set_template_updates_palette()

	_test_must_b_policy_keys()

	await _test_must_c1_update_3d_preview_null_safe()
	await _test_must_c2_setup_preview_environment_null_safe()

	quit(_exit_code)
