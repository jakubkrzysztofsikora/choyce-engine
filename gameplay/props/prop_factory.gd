class_name PropFactory
extends RefCounted
## Builds fully-componented sandbox props procedurally.
##
## This is the file that proves the thesis of the whole architecture: a bare
## mesh + a handful of component nodes = a first-class sandbox object that all
## four players can grab, throw, hit, destroy and interact with. When real art
## arrives, only the visual mount changes.

const CRATE_VISUAL := preload("res://data/models/quaternius/medieval_village/Prop_Crate.gltf")
const BARREL_VISUAL := preload("res://data/models/kenney/survival_kit/Models/GLB format/barrel.glb")

static func make_crate(size: float = 0.8, colour: Color = Color("#d8a05a"),
		health: float = 30.0, mass: float = 6.0) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "Crate"
	body.mass = mass
	body.collision_layer = Layers.PROP_DYNAMIC | Layers.GRAB_TARGET | Layers.INTERACT_TRIGGER
	body.collision_mask = Layers.SOLID_WORLD | Layers.PROP_DYNAMIC | Layers.PLAYER_BODY | Layers.VEHICLE
	body.can_sleep = true

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3.ONE * size
	cs.shape = bs
	body.add_child(cs)

	_mount_visual(body, CRATE_VISUAL, Vector3.ONE * size)

	# --- components: this block is the entire "make it a sandbox object" step
	var hp := HealthComponent.new()
	hp.name = "HealthComponent"
	var cfg := HealthConfig.new()
	cfg.max_health = health
	hp.config = cfg
	body.add_child(hp)

	var team := TeamComponent.new()
	team.name = "TeamComponent"
	body.add_child(team)

	var grab := GrabComponent.new()
	grab.name = "GrabComponent"
	grab.mass_class = GrabComponent.MassClass.LIGHT
	body.add_child(grab)

	var inter := InteractableComponent.new()
	inter.name = "InteractableComponent"
	inter.prompt_text = "Pick up"
	inter.interaction_range = 3.5
	body.add_child(inter)

	var hl := HighlightComponent.new()
	hl.name = "HighlightComponent"
	body.add_child(hl)

	var fx := FXComponent.new()
	fx.name = "FXComponent"
	body.add_child(fx)

	var dest := DestructibleComponent.new()
	dest.name = "DestructibleComponent"
	dest.fallback_shard_count = 6
	dest.burst_impulse = 3.5
	body.add_child(dest)

	var style := StylizedMaterialComponent.new()
	style.name = "StylizedMaterialComponent"
	body.add_child(style)

	return body


static func make_barrel(colour: Color = Color("#c1524a")) -> RigidBody3D:
	var body := make_crate(1.0, colour, 22.0, 9.0)
	body.name = "Barrel"
	var crate_visual := body.get_node_or_null("PropVisual")
	if crate_visual != null:
		crate_visual.free()
		_mount_visual(body, BARREL_VISUAL, Vector3.ONE * 0.9)
	return body


static func _mount_visual(body: RigidBody3D, scene: PackedScene, visual_scale: Vector3) -> void:
	var visual_root := Node3D.new()
	visual_root.name = "PropVisual"
	visual_root.scale = visual_scale
	body.add_child(visual_root)
	var visual := scene.instantiate() as Node3D
	if visual != null:
		visual_root.add_child(visual)
