## Pure-data HP state. Lives on player and every enemy. RefCounted —
## no Godot Node coupling. Damage / heal / kill events flow through
## DomainEventBus via the adapter that owns the matching CharacterBody3D.
##
## Kid-safe design (CLAUDE.md global rule + 7yo target):
## - Defeat = poof to stars/sparkles, NOT death/gore.
## - Player HP regenerates over time (no game-over screen, no respawn
##   menu — just soft fade + return to last checkpoint).
## - Enemies never deal damage > player.max_hp / 3 in one hit
##   (kid-friendly difficulty curve enforced at this layer).
class_name HealthState
extends RefCounted

var max_hp: int
var current_hp: int
var invuln_remaining: float  ## seconds of invulnerability after last hit
var is_alive: bool


func _init(p_max_hp: int = 100) -> void:
	max_hp = max(p_max_hp, 1)
	current_hp = max_hp
	invuln_remaining = 0.0
	is_alive = true


## Apply damage. Returns true if the hit landed (was not blocked by
## invulnerability frames). Caps damage at max_hp/3 per the kid-safe
## difficulty contract.
func apply_damage(amount: int) -> bool:
	if not is_alive or invuln_remaining > 0.0:
		return false
	var capped := mini(amount, maxi(int(max_hp / 3), 1))
	current_hp = maxi(current_hp - capped, 0)
	invuln_remaining = 0.4  ## 400 ms iframes — standard Zelda/Mario feel
	if current_hp <= 0:
		is_alive = false
	return true


func heal(amount: int) -> void:
	if not is_alive:
		return
	current_hp = mini(current_hp + maxi(amount, 0), max_hp)


## Called once per frame by the owning adapter. Decays iframes; rolls
## over HP regen for the player only (call regen_per_second > 0 to
## opt in; enemies stay at regen=0).
func tick(delta: float, regen_per_second: float = 0.0) -> void:
	if not is_alive:
		return
	if invuln_remaining > 0.0:
		invuln_remaining = maxf(invuln_remaining - delta, 0.0)
	if regen_per_second > 0.0 and current_hp < max_hp:
		current_hp = mini(current_hp + int(regen_per_second * delta + 0.5), max_hp)


func hp_fraction() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)
