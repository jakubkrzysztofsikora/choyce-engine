class_name GraphicsProfile
extends Resource
## Quality tiers, indexed by ACTIVE PLAYER COUNT.
##
## Tuned from the Spike A measurement on this machine (Godot 4.6.1, Forward+,
## 200 dynamic bodies, 1152x648):
##
##   1 pane, full window : 118 fps,   800 draw calls,  26,854 primitives
##   4 panes, quarter each:  63 fps, 3,230 draw calls, 290,296 primitives
##
## Total pixels rendered were IDENTICAL. Frame time still rose ~1.87x.
## Primitives rose 10.8x from a 4x increase in views — that is shadow work:
## each viewport re-renders every directional shadow cascade from scratch.
##
## CONSEQUENCE, and it is counter-intuitive: lowering SubViewport resolution
## barely helps, because the cost is per-view CPU and shadow passes, not fill
## rate. Cascade count and shadow distance are the high-leverage knobs. This
## resource exists to encode that finding so nobody re-derives it later.

@export var shadow_splits: Array[int] = [4, 4, 2, 2]        ## by player count 1..4
@export var shadow_max_distance: Array[float] = [120.0, 90.0, 60.0, 45.0]
@export var shadow_atlas_size: Array[int] = [4096, 4096, 2048, 2048]
@export var sdfgi: Array[bool] = [true, true, false, false]
@export var volumetric_fog: Array[bool] = [true, true, false, false]
@export var ssao: Array[bool] = [true, true, true, false]
@export var ssil: Array[bool] = [true, false, false, false]
## Resolution scale is listed LAST deliberately — it is the weakest lever here.
@export var render_scale: Array[float] = [1.0, 1.0, 0.9, 0.85]


func _idx(player_count: int) -> int:
	return clampi(player_count - 1, 0, 3)


func splits_for(player_count: int) -> int:
	return shadow_splits[_idx(player_count)]


func shadow_distance_for(player_count: int) -> float:
	return shadow_max_distance[_idx(player_count)]


func atlas_for(player_count: int) -> int:
	return shadow_atlas_size[_idx(player_count)]


func sdfgi_for(player_count: int) -> bool:
	return sdfgi[_idx(player_count)]


func fog_for(player_count: int) -> bool:
	return volumetric_fog[_idx(player_count)]


func ssao_for(player_count: int) -> bool:
	return ssao[_idx(player_count)]


func ssil_for(player_count: int) -> bool:
	return ssil[_idx(player_count)]


func scale_for(player_count: int) -> float:
	return render_scale[_idx(player_count)]
