extends Node

# Autoload-only singleton; do NOT declare class_name — would collide with the
# autoload of the same name. Access globally via the autoload identifier
# `ButtonFeel` declared in project.godot.

## Autoload singleton — adds scale-bounce feel to every Button in the app.
##
## Auto-wires any Button that enters the scene tree.
## Opt-out: set meta "skip_button_feel" = true on the button.
## Manual wire: ButtonFeel.attach(button)
##
## SFX: interested listeners connect ButtonFeel.press.connect(_on_btn_pressed)
## where _on_btn_pressed(btn) can find SFXPlayer and call play("ui_click").

signal press(button: Button)

const SCALE_DOWN := Vector2(0.94, 0.94)
const SCALE_UP := Vector2(1.0, 1.0)
const DOWN_TIME := 0.08
const UP_TIME := 0.18

const _WIRED_META := "button_feel_wired"
const _SKIP_META := "skip_button_feel"

func _ready() -> void:
	# Wire buttons already present before autoload finished loading
	for node in get_tree().get_nodes_in_group("buttons"):
		_try_attach(node)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	_try_attach(node)

func _try_attach(node: Node) -> void:
	if node is Button or node is CheckButton or node is OptionButton:
		attach(node as Button)

## Attach scale-bounce behaviour to a specific Button.
## Safe to call multiple times — subsequent calls are no-ops.
func attach(btn: Button) -> void:
	if btn.has_meta(_WIRED_META):
		return
	if btn.has_meta(_SKIP_META):
		return

	btn.set_meta(_WIRED_META, true)

	# Set pivot to centre so scale animates from the middle, not top-left.
	if btn.size != Vector2.ZERO:
		btn.pivot_offset = btn.size / 2.0
	# Keep pivot centred if the button is later resized (e.g. during layout).
	btn.resized.connect(func() -> void:
		btn.pivot_offset = btn.size / 2.0
	)

	btn.button_down.connect(func() -> void: _on_down(btn))
	btn.button_up.connect(func() -> void: _on_up(btn))
	btn.focus_exited.connect(func() -> void: _on_up(btn))

func _on_down(btn: Button) -> void:
	var tw := btn.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", SCALE_DOWN, DOWN_TIME)

func _on_up(btn: Button) -> void:
	var tw := btn.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", SCALE_UP, UP_TIME)
	emit_press(btn)

## Fire the global press signal. SFXPlayer listeners can hook here.
func emit_press(btn: Button) -> void:
	press.emit(btn)
