## Value object representing an age-based restriction tier.
## Used across Identity & Safety and AI Orchestration contexts
## to enforce age-appropriate policies.
class_name AgeBand
extends RefCounted

enum Band {
	CHILD_6_8,
	CHILD_9_12,
	TEEN,
	PARENT,
}

var band: Band
var min_age: int
var max_age: int


func _init(p_band: Band = Band.CHILD_6_8) -> void:
	band = p_band
	match band:
		Band.CHILD_6_8:
			min_age = 6
			max_age = 8
		Band.CHILD_9_12:
			min_age = 9
			max_age = 12
		Band.TEEN:
			min_age = 13
			max_age = 17
		Band.PARENT:
			min_age = 18
			max_age = -1


func is_child() -> bool:
	return band in [Band.CHILD_6_8, Band.CHILD_9_12]


func is_restricted() -> bool:
	return band == Band.CHILD_6_8


func equals(other: AgeBand) -> bool:
	return other != null and band == other.band
