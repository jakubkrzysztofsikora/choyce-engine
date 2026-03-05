## Outbound port for managing accessibility features and compliance state.
## Implementations modify the global Theme, managing overlays, and enforcing WCAG parameters.
class_name AccessibilityPolicyPort
extends RefCounted


## Applies the base WCAG AA contrast theme
func apply_baseline_contrast() -> void:
	pass


## Toggles the Dyslexia-friendly font override
## @param enabled: If true, loads OpenDyslexic or similar; else reverts to default
func set_dyslexia_font(enabled: bool) -> void:
	pass


## Adjusts UI scale and touch target padding for motor impairment support
## @param scale_factor: > 1.0 increases size (e.g. 1.2, 1.5)
func set_motor_scale(scale_factor: float) -> void:
	pass


## Toggles the visibility of the captions overlay system
## @param enabled: If true, show_caption() calls will render text
func set_captions_enabled(enabled: bool) -> void:
	pass


## Requests a caption to be displayed (if enabled)
## @param text: The spoken content or sound description
## @param duration: Time in seconds to display
func show_caption(text: String, duration: float = 3.0) -> void:
	pass
