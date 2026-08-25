class_name PropFactory
extends RefCounted
## Builds fully-componented sandbox props procedurally.
##
## This is the file that proves the thesis of the whole architecture: a bare
## mesh + a handful of component nodes = a first-class sandbox object that all
## four players can grab, throw, hit, destroy and interact with. When real art
## arrives, only the mesh line changes.

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

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.7
	mi.material_override = mat
	body.add_child(mi)

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
	var mi := body.get_node_or_null("Mesh") as MeshInstance3D
	if mi:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.45
		cm.bottom_radius = 0.45
		cm.height = 1.1
		mi.mesh = cm
	return body
