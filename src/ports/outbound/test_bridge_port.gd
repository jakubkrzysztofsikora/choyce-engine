class_name TestBridgePort
extends Node

## Outbound port for AI test agent state inspection and control.
##
## All methods return safe no-ops in production. The debug adapter wired by
## FeatureFlagService.is_enabled("debug_test_bridge") overrides these.
##
## Hexagonal rule: no domain types are exposed through this port. State is
## serialised to plain Dictionary / PackedByteArray before leaving the domain.


## Returns current application state as a flat Dictionary suitable for JSON
## serialisation by an external test agent. Keys follow section.field notation.
func get_game_state() -> Dictionary:
	return {}


## Captures the current display frame as a PNG-encoded byte array.
## Returns empty array when running headless without a display.
func capture_screenshot() -> PackedByteArray:
	return PackedByteArray()


## Injects a synthetic input event into the engine input queue.
## p_event keys: type ("mouse_button"|"key"|"mouse_motion"),
##               button_index (for mouse_button),
##               keycode (for key),
##               position (for mouse events, normalised 0..1),
##               pressed (bool).
## Returns true if the event was accepted, false if the bridge is disabled.
func inject_input(p_event: Dictionary) -> bool:
	return false


## Pushes an arbitrary key-value section into the GSI state stream so that
## external agents can observe domain events as discrete state updates.
## p_section: dot-separated section name (e.g. "safety.moderation")
## p_data: serialisable Dictionary with current values for that section.
func set_state_section(p_section: String, p_data: Dictionary) -> void:
	pass
