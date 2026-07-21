## Service handling settlement spatial layout: candidate placement generation,
## proximity clustering (R_min <= d <= R_max), slope validation, and AABB collision checking.
##
## HEIGHT CONTRACT: this service owns XZ layout only. Every returned position
## carries UNGROUNDED_Y as its y component; the caller MUST ground each
## placement at its final XZ (e.g. WorldRenderer._terrain_grounded_position)
## before placing nodes. Derived placements used to copy the anchor
## homestead's y, which made compounds 2..N float or sink on sloped terrain.
class_name SettlementPlacementService
extends RefCounted

const DEFAULT_MIN_DISTANCE := 12.0
const DEFAULT_MAX_DISTANCE := 45.0
const DEFAULT_FOOTPRINT_RADIUS := 6.0
const MAX_PLACEMENT_ATTEMPTS := 30

## Sentinel y meaning "not terrain-grounded yet". Deliberately not 0.0 (a
## valid flat-ground height) so an ungrounded placement can never pass as a
## grounded one by accident.
const UNGROUNDED_Y := -INF


## Calculates a candidate position relative to existing homesteads within a target proximity.
func find_valid_placement(
	center: Vector3,
	existing_homesteads: Array, # Array of HomesteadSpec or Vector3
	min_dist: float = DEFAULT_MIN_DISTANCE,
	max_dist: float = DEFAULT_MAX_DISTANCE,
	footprint_radius: float = DEFAULT_FOOTPRINT_RADIUS,
	rng: RandomNumberGenerator = null
) -> Vector3:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	# Extract positions of existing homesteads
	var occupied_positions: Array[Vector3] = []
	for item in existing_homesteads:
		if item is Vector3:
			occupied_positions.append(item as Vector3)
		elif item != null and "position" in item:
			occupied_positions.append(item.position)

	# If no existing homesteads, place near center
	if occupied_positions.is_empty():
		return Vector3(
			center.x + rng.randf_range(-3.0, 3.0),
			UNGROUNDED_Y,
			center.z + rng.randf_range(-3.0, 3.0))

	for attempt in range(MAX_PLACEMENT_ATTEMPTS):
		# Pick an anchor homestead to cluster around
		var anchor: Vector3 = occupied_positions[rng.randi_range(0, occupied_positions.size() - 1)]
		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(min_dist, max_dist)
		# XZ layout only: never copy anchor.y — the anchor sits at ITS OWN
		# terrain height, which is wrong for this candidate on any slope.
		var candidate := Vector3(anchor.x + cos(angle) * dist, UNGROUNDED_Y, anchor.z + sin(angle) * dist)

		# Check distance to ALL existing homesteads to avoid collision
		var overlaps := false
		for occ in occupied_positions:
			var d_xz := Vector2(candidate.x - occ.x, candidate.z - occ.z).length()
			if d_xz < (min_dist * 0.75):
				overlaps = true
				break

		if not overlaps:
			return candidate

	# Fallback if attempts exhausted
	var fallback_angle := rng.randf_range(0.0, TAU)
	return Vector3(
		center.x + cos(fallback_angle) * max_dist,
		UNGROUNDED_Y,
		center.z + sin(fallback_angle) * max_dist)
