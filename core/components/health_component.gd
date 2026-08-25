class_name HealthComponent
extends SandboxComponent
## Drop on anything that can be hurt: players, NPCs, placed blocks, props,
## vehicles. Knows nothing about what it is attached to.

signal damaged(info: DamageInfo, remaining: float)
signal healed(amount: float, remaining: float)
signal died(info: DamageInfo)

@export var config: HealthConfig
@export var start_full: bool = true

var current: float = 0.0
var is_dead: bool = false


func _component_key() -> StringName:
	return Components.HEALTH


func _on_registered() -> void:
	if config == null:
		config = HealthConfig.new()
	current = config.max_health if start_full else current


func apply(info: DamageInfo) -> void:
	if is_dead or config.invulnerable or info == null:
		return

	if not config.friendly_fire and info.source_team >= 0:
		var team := sibling(Components.TEAM)
		if team and team.team_id == info.source_team:
			return

	var mult := 1.0
	var idx := int(info.type)
	if idx >= 0 and idx < config.type_multipliers.size():
		mult = config.type_multipliers[idx]

	var dmg := info.final_amount() * mult
	if dmg < config.damage_threshold:
		return

	current = maxf(0.0, current - dmg)
	damaged.emit(info, current)

	if current <= 0.0:
		is_dead = true
		died.emit(info)


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current = minf(config.max_health, current + amount)
	healed.emit(amount, current)


func revive(to_fraction: float = 1.0) -> void:
	is_dead = false
	current = config.max_health * clampf(to_fraction, 0.01, 1.0)


func fraction() -> float:
	return 0.0 if config.max_health <= 0.0 else current / config.max_health
