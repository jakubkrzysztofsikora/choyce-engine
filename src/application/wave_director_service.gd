## Wave director — consumes Array[WaveConfig] and produces next-wave
## payloads on demand. Replaces the hardcoded scaling formulas
## inside gameplay_runtime._spawn_next_wave (Adv 1 H1 fix).
##
## RNG seeded by run_seed + wave_index for reproducible runs —
## procedural-research synthesis says this is the production
## pattern (Brotato ContentLoader). Tests can replay a kid's run
## by re-seeding.
##
## Hex-clean — no Godot Node. Returns plain dicts the adapter
## consumes to instantiate enemies.
class_name WaveDirectorService
extends RefCounted


## Compute the spawn plan for the given wave_number. Returns a
## Dictionary:
##   {
##     "wave_number": int,
##     "pack_size": int,
##     "hp_mult": float,
##     "speed_mult": float,
##     "is_boss_wave": bool,
##     "archetype_weights": Dictionary[String, float],
##   }
##
## If `waves` is empty, fall back to the procedural-research default
## curve. If a config exists for the exact wave number, use it
## verbatim. Otherwise extrapolate from the highest authored wave.
func plan_wave(waves: Array, wave_number: int) -> Dictionary:
	for w in waves:
		if w is WaveConfig and (w as WaveConfig).wave_number == wave_number:
			return _config_to_dict(w as WaveConfig)
	# Procedural fallback for waves the parent didn't author.
	return _procedural_plan(wave_number)


## Honor ParentalControlPolicy.combat_wave_cap — 0 = no extra waves
## past the starter pack, non-zero = hard cap.
func is_capped(wave_number: int, cap: int) -> bool:
	if cap <= 0:
		return wave_number > 0   ## 0 = no extra waves at all
	return wave_number >= cap


# ---- internals ----

func _config_to_dict(c: WaveConfig) -> Dictionary:
	return {
		"wave_number": c.wave_number,
		"pack_size": c.pack_size,
		"hp_mult": c.hp_mult,
		"speed_mult": c.speed_mult,
		"is_boss_wave": c.is_boss_wave,
		"archetype_weights": c.archetype_weights,
	}


## Kid-friendly difficulty curve from procedural-research:
##   count = 3 + N * 1.2 (cap 7 to keep iPad-class GPU happy)
##   hp_mult = 1 + sqrt(N) * 0.25
##   speed_mult = clamp(1 + N * 0.04, 1.0, 1.4)
##   boss every 5th wave
func _procedural_plan(n: int) -> Dictionary:
	var count := mini(int(3 + n * 1.2), 7)
	var hp_mult := 1.0 + sqrt(float(n)) * 0.25
	var speed_mult: float = clampf(1.0 + n * 0.04, 1.0, 1.4)
	var is_boss := n > 0 and (n % 5) == 0
	var weights := {
		"slime_green": 1.0,
		"bouncer_pink": 0.4 + n * 0.03,
		"slime_blue": maxf(0.0, n - 2.0) * 0.2,
	}
	return {
		"wave_number": n,
		"pack_size": count,
		"hp_mult": hp_mult,
		"speed_mult": speed_mult,
		"is_boss_wave": is_boss,
		"archetype_weights": weights,
	}
