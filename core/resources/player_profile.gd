class_name SandboxPlayerProfile
extends Resource
## One logical player. Created by PlayerRegistry on join, destroyed on leave.
## Everything downstream (camera, HUD, build cursor, audio pan) keys off this.

@export var player_id: int = 0            ## 0..3, stable for the session
@export var device_id: int = -1           ## -1 keyboard, 0..7 joypad
@export var display_name: String = ""
@export var colour: Color = Color.WHITE
@export var character_scene: PackedScene = null

## Runtime, not serialized.
var body: Node3D = null
var viewport: SubViewport = null
var camera: Camera3D = null
## Aim pivot: sits at the player's head and carries the look yaw/pitch.
## EVERY gameplay ray (interact, grab, build ghost, melee) originates here and
## points along -aim.basis.z. Casting from the CAMERA instead sends the ray from
## behind the player, through their head, and out the far side — you end up
## targeting whatever is behind you, and the build ghost sticks to your feet.
var aim: Node3D = null


## Aim origin/direction with a safe fallback, so systems never have to know
## whether the player rig is fully constructed yet.
func aim_origin() -> Vector3:
	if is_instance_valid(aim):
		return aim.global_position
	if is_instance_valid(body):
		return body.global_position + Vector3.UP
	return Vector3.ZERO


func aim_direction() -> Vector3:
	if is_instance_valid(aim):
		return -aim.global_transform.basis.z
	if is_instance_valid(body):
		return -body.global_transform.basis.z
	return Vector3.FORWARD


static func make(p_id: int, p_device: int) -> SandboxPlayerProfile:
	var p := SandboxPlayerProfile.new()
	p.player_id = p_id
	p.device_id = p_device
	p.display_name = "Player %d" % (p_id + 1)
	p.colour = PALETTE[p_id % PALETTE.size()]
	return p


const PALETTE: Array[Color] = [
	Color("#ff6b4a"),  # P1 coral
	Color("#4ac8ff"),  # P2 cyan
	Color("#9dff4a"),  # P3 lime
	Color("#ffd84a"),  # P4 amber
]
