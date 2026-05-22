## Adv Y C1/C2/C4 — combat feel hit-feedback tests.
## Verifies that `_on_enemy_damaged` (every successful swing landing
## on an alive enemy) fires hit-stop, fires the punch_thud SFX (not
## the coin pickup chime), and triggers a stronger shake than the
## previous 3.0/0.06 invisible default.
##
## We hand-build a GameplayRuntime instance, stub the audio bus +
## screen feedback collaborators, then call _on_enemy_damaged
## directly. Time-scale is captured BEFORE the SceneTreeTimer that
## reverts it can fire, so we observe the dip live.
extends SceneTree


const GameplayRuntime = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.gd")
const AudioEventBus = preload("res://src/adapters/inbound/gameplay/audio_event_bus.gd")


## Subclasses the real ScreenFeedback so the statically-typed
## `_screen_feedback: ScreenFeedback` field on GameplayRuntime
## accepts it. Overrides shake/shake_directional to record calls
## without touching the viewport (no camera in unit-test land).
class StubScreenFeedback extends ScreenFeedback:
	var shake_calls: Array = []
	var directional_calls: Array = []
	func shake(intensity: float = 8.0, duration: float = 0.3) -> void:
		shake_calls.append({"intensity": intensity, "duration": duration})
	func shake_directional(intensity: float = 6.0, duration: float = 0.08,
			direction: Vector2 = Vector2.ZERO) -> void:
		directional_calls.append({"intensity": intensity, "duration": duration, "direction": direction})


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Reset time_scale defensively so a leaked dip from a prior test
	# can't false-pass this one.
	Engine.time_scale = 1.0
	_test_hit_stop_fires_on_hit()
	_test_punch_thud_sfx_on_hit()
	_test_directional_shake_on_hit()
	print("ALL_COMBAT_HIT_FEEDBACK_TESTS: PASS")
	quit(0)


func _make_runtime() -> Node3D:
	# GameplayRuntime extends Node3D — must instantiate a Node3D and
	# attach the script, not a bare Node (set_script enforces the
	# native base type of the script).
	var rt := Node3D.new()
	rt.set_script(GameplayRuntime)
	# Bypass _ready() — we never add to tree. Wire the fields the
	# handler reads directly.
	var bus := AudioEventBus.new()
	rt.set("_audio_bus", bus)
	var sfb := StubScreenFeedback.new()
	rt.set("_screen_feedback", sfb)
	return rt


## C1 — _on_enemy_damaged MUST dip Engine.time_scale (hit-stop). Was
## previously firing only on kill — the single largest missing feel
## signal per Adv Y.
func _test_hit_stop_fires_on_hit() -> void:
	var rt := _make_runtime()
	Engine.time_scale = 1.0
	rt.call("_on_enemy_damaged", 4, Vector3(1, 0, 0))
	if not is_equal_approx(Engine.time_scale, 0.15):
		printerr("FAIL C1: Engine.time_scale expected 0.15, got %f" % Engine.time_scale)
		quit(1)
	Engine.time_scale = 1.0


## C2 — _on_enemy_damaged MUST emit "punch_thud", NOT "collect"
## (which is the coin pickup chime).
func _test_punch_thud_sfx_on_hit() -> void:
	var rt := _make_runtime()
	Engine.time_scale = 1.0
	var bus: AudioEventBus = rt.get("_audio_bus")
	var captured: Array = []
	bus.play_sfx.connect(func(event_name: String, _pos: Vector3) -> void:
		captured.append(event_name)
	)
	rt.call("_on_enemy_damaged", 4, Vector3(1, 0, 0))
	if not captured.has("punch_thud"):
		printerr("FAIL C2: expected punch_thud, got %s" % str(captured))
		quit(1)
	if captured.has("collect"):
		printerr("FAIL C2: hit SFX must NOT be the coin pickup chime")
		quit(1)
	Engine.time_scale = 1.0


## C4 — _on_enemy_damaged MUST trigger a shake (directional path
## when available). Per-hit shake is now the loud one (6.0/0.08)
## not the old invisible 3.0/0.06.
func _test_directional_shake_on_hit() -> void:
	var rt := _make_runtime()
	Engine.time_scale = 1.0
	var sfb: StubScreenFeedback = rt.get("_screen_feedback")
	rt.call("_on_enemy_damaged", 4, Vector3(2, 0, 0))
	if sfb.directional_calls.is_empty():
		printerr("FAIL C4: expected shake_directional to fire")
		quit(1)
	var call0: Dictionary = sfb.directional_calls[0]
	if call0["intensity"] < 5.0:
		printerr("FAIL C4: shake intensity %f too weak (need ≥5)" % call0["intensity"])
		quit(1)
	Engine.time_scale = 1.0
