## Shared helper: re-anchor a Control as a centered max-width band
## so ultra-wide monitors (3440px+) don't stretch shell content
## edge-to-edge. Applied to LandingScreen, CreateShell, PlayShell,
## ParentZoneShell, LibraryShell.
##
## Mutates anchors in place; preserves the node identity so
## @onready paths upstream still resolve.
class_name ResponsiveLayout
extends RefCounted


const DEFAULT_MAX_WIDTH := 1280.0


static func apply_max_width(node: Control, max_width: float = DEFAULT_MAX_WIDTH) -> void:
	if node == null:
		return
	node.anchor_left = 0.5
	node.anchor_right = 0.5
	node.anchor_top = 0.0
	node.anchor_bottom = 1.0
	node.offset_left = -max_width * 0.5
	node.offset_right = max_width * 0.5
	node.offset_top = 16.0
	node.offset_bottom = -16.0
	node.grow_horizontal = Control.GROW_DIRECTION_BOTH
