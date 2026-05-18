## Application service: computes monthly usability KPIs for child-parent playtests.
## Outputs product and safety-oriented summaries for recurring review workflows.
class_name UsabilityKPIReportingService
extends RefCounted

const TARGET_AGE_BAND := "6-8"
const LOOP_COMPLETION_MAX_SECONDS := 900.0
const LOOP_COMPLETION_MIN_RATE := 0.8


func build_monthly_report(month_id: String, sessions: Array) -> Dictionary:
	var clean_month := month_id.strip_edges()
	if clean_month.is_empty():
		clean_month = Time.get_date_string_from_system().substr(0, 7)

	var filtered_sessions := _filter_target_sessions(sessions)
	var sample_size := filtered_sessions.size()

	if sample_size == 0:
		return {
			"month_id": clean_month,
			"target_age_band": TARGET_AGE_BAND,
			"sample_size": 0,
			"kpis": {},
			"thresholds": {
				"first_playable_loop_within_15m_min_rate": LOOP_COMPLETION_MIN_RATE,
			},
			"benchmarks": {
				"mvp_first_playable_loop_within_15m_pass": false,
			},
			"workflow_views": {
				"product": {},
				"safety": {},
			},
			"warnings": ["no_eligible_sessions"],
		}

	var first_fun_seconds: Array[float] = []
	var completed_within_15m := 0
	var completed_without_rescue := 0
	var rescued_sessions := 0
	var frustration_sessions := 0
	var trust_sum := 0.0
	var trust_samples := 0
	var low_trust_sessions := 0

	for entry_variant in filtered_sessions:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant

		var first_fun := float(entry.get("time_to_first_fun_seconds", 0.0))
		if first_fun > 0.0:
			first_fun_seconds.append(first_fun)

		var loop_completed := bool(entry.get("loop_completed", false))
		var loop_seconds := float(entry.get("first_playable_loop_seconds", 0.0))
		var rescue_count: int = maxi(int(entry.get("adult_rescue_count", 0)), 0)
		var trust_score := float(entry.get("parent_trust_score", 0.0))

		if loop_completed and loop_seconds > 0.0 and loop_seconds <= LOOP_COMPLETION_MAX_SECONDS:
			completed_within_15m += 1
		if loop_completed and rescue_count == 0:
			completed_without_rescue += 1
		if rescue_count > 0:
			rescued_sessions += 1

		if _has_frustration_signal(entry.get("frustration", {})):
			frustration_sessions += 1

		if trust_score > 0.0:
			trust_sum += trust_score
			trust_samples += 1
			if trust_score <= 2.0:
				low_trust_sessions += 1

	var loop_completion_rate := _rate(completed_within_15m, sample_size)
	var completion_without_rescue_rate := _rate(completed_without_rescue, sample_size)
	var adult_rescue_rate := _rate(rescued_sessions, sample_size)
	var frustration_signal_rate := _rate(frustration_sessions, sample_size)
	var parent_trust_avg := 0.0
	if trust_samples > 0:
		parent_trust_avg = trust_sum / float(trust_samples)
	var low_trust_rate := _rate(low_trust_sessions, sample_size)

	var kpis := {
		"time_to_first_fun_median_seconds": _round_to(_median(first_fun_seconds), 2),
		"first_playable_loop_within_15m_rate": _round_to(loop_completion_rate, 3),
		"completion_without_adult_rescue_rate": _round_to(completion_without_rescue_rate, 3),
		"adult_rescue_rate": _round_to(adult_rescue_rate, 3),
		"parent_trust_score_avg": _round_to(parent_trust_avg, 3),
		"frustration_signal_rate": _round_to(frustration_signal_rate, 3),
		"low_trust_session_rate": _round_to(low_trust_rate, 3),
	}

	return {
		"month_id": clean_month,
		"target_age_band": TARGET_AGE_BAND,
		"sample_size": sample_size,
		"thresholds": {
			"first_playable_loop_within_15m_min_rate": LOOP_COMPLETION_MIN_RATE,
		},
		"kpis": kpis,
		"benchmarks": {
			"mvp_first_playable_loop_within_15m_pass": loop_completion_rate >= LOOP_COMPLETION_MIN_RATE,
		},
		"workflow_views": {
			"product": {
				"time_to_first_fun_median_seconds": kpis["time_to_first_fun_median_seconds"],
				"completion_without_adult_rescue_rate": kpis["completion_without_adult_rescue_rate"],
				"frustration_signal_rate": kpis["frustration_signal_rate"],
			},
			"safety": {
				"parent_trust_score_avg": kpis["parent_trust_score_avg"],
				"low_trust_session_rate": kpis["low_trust_session_rate"],
				"adult_rescue_rate": kpis["adult_rescue_rate"],
				"frustration_signal_rate": kpis["frustration_signal_rate"],
			},
		},
	}


func _filter_target_sessions(sessions: Array) -> Array:
	var filtered: Array = []
	for row_variant in sessions:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant
		var session_id := str(row.get("session_id", "")).strip_edges()
		var age_band := str(row.get("age_band", "")).strip_edges()
		if session_id.is_empty():
			continue
		if age_band != TARGET_AGE_BAND:
			continue
		filtered.append(row)
	return filtered


func _has_frustration_signal(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var frustration: Dictionary = value
	var rage_taps: int = maxi(int(frustration.get("rage_taps", 0)), 0)
	var abandoned := bool(frustration.get("abandoned", false))
	return rage_taps >= 3 or abandoned


func _rate(count: int, total: int) -> float:
	if total <= 0:
		return 0.0
	return float(count) / float(total)


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values: Array[float] = values.duplicate()
	sorted_values.sort()
	var middle := sorted_values.size() / 2
	if sorted_values.size() % 2 == 1:
		return sorted_values[middle]
	return (sorted_values[middle - 1] + sorted_values[middle]) / 2.0


func _round_to(value: float, digits: int) -> float:
	var factor := pow(10.0, float(digits))
	return round(value * factor) / factor
