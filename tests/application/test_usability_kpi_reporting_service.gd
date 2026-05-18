extends ApplicationTest

const ServiceScn = preload("res://src/application/usability_kpi_reporting_service.gd")


func run() -> Dictionary:
	_test_monthly_kpi_report_values()
	_test_invalid_and_non_target_sessions_are_filtered()
	_test_mvp_benchmark_failure_flag()
	return _build_result("UsabilityKPIReportingService")


func _test_monthly_kpi_report_values() -> void:
	var service = ServiceScn.new()
	var sessions: Array = [
		{
			"session_id": "s-1",
			"age_band": "6-8",
			"time_to_first_fun_seconds": 120,
			"first_playable_loop_seconds": 540,
			"loop_completed": true,
			"adult_rescue_count": 0,
			"parent_trust_score": 5,
			"frustration": {"rage_taps": 0, "abandoned": false},
		},
		{
			"session_id": "s-2",
			"age_band": "6-8",
			"time_to_first_fun_seconds": 180,
			"first_playable_loop_seconds": 780,
			"loop_completed": true,
			"adult_rescue_count": 0,
			"parent_trust_score": 4,
			"frustration": {"rage_taps": 1, "abandoned": false},
		},
		{
			"session_id": "s-3",
			"age_band": "6-8",
			"time_to_first_fun_seconds": 300,
			"first_playable_loop_seconds": 850,
			"loop_completed": true,
			"adult_rescue_count": 1,
			"parent_trust_score": 3,
			"frustration": {"rage_taps": 4, "abandoned": false},
		},
		{
			"session_id": "s-4",
			"age_band": "6-8",
			"time_to_first_fun_seconds": 240,
			"first_playable_loop_seconds": 700,
			"loop_completed": true,
			"adult_rescue_count": 0,
			"parent_trust_score": 5,
			"frustration": {"rage_taps": 0, "abandoned": false},
		},
		{
			"session_id": "s-5",
			"age_band": "6-8",
			"time_to_first_fun_seconds": 360,
			"first_playable_loop_seconds": 0,
			"loop_completed": false,
			"adult_rescue_count": 2,
			"parent_trust_score": 2,
			"frustration": {"rage_taps": 5, "abandoned": true},
		},
	]

	var report: Dictionary = service.build_monthly_report("2026-03", sessions)
	var kpis: Dictionary = report.get("kpis", {})
	var benchmarks: Dictionary = report.get("benchmarks", {})

	_assert_eq(report.get("sample_size", 0), 5, "Sample size should include all 6-8 sessions")
	_assert_eq(
		kpis.get("time_to_first_fun_median_seconds", 0.0),
		240.0,
		"Median first-fun time should match deterministic fixture"
	)
	_assert_eq(
		kpis.get("first_playable_loop_within_15m_rate", 0.0),
		0.8,
		"Loop completion <=15m rate should match fixture"
	)
	_assert_eq(
		kpis.get("completion_without_adult_rescue_rate", 0.0),
		0.6,
		"Completion-without-rescue rate should match fixture"
	)
	_assert_eq(
		kpis.get("adult_rescue_rate", 0.0),
		0.4,
		"Adult rescue rate should match fixture"
	)
	_assert_eq(
		kpis.get("frustration_signal_rate", 0.0),
		0.4,
		"Frustration signal rate should match fixture"
	)
	_assert_eq(
		kpis.get("parent_trust_score_avg", 0.0),
		3.8,
		"Parent trust average should match fixture"
	)
	_assert_true(
		bool(benchmarks.get("mvp_first_playable_loop_within_15m_pass", false)),
		"MVP benchmark should pass for 0.8 rate"
	)


func _test_invalid_and_non_target_sessions_are_filtered() -> void:
	var service = ServiceScn.new()
	var sessions: Array = [
		{
			"session_id": "valid-1",
			"age_band": "6-8",
			"time_to_first_fun_seconds": 100,
			"first_playable_loop_seconds": 600,
			"loop_completed": true,
			"adult_rescue_count": 0,
			"parent_trust_score": 4,
			"frustration": {"rage_taps": 0, "abandoned": false},
		},
		{
			"session_id": "older-group",
			"age_band": "9-11",
			"time_to_first_fun_seconds": 90,
			"first_playable_loop_seconds": 550,
			"loop_completed": true,
			"adult_rescue_count": 0,
			"parent_trust_score": 5,
			"frustration": {"rage_taps": 0, "abandoned": false},
		},
		{
			"session_id": "valid-2",
			"age_band": "6-8",
			"time_to_first_fun_seconds": 130,
			"first_playable_loop_seconds": 610,
			"loop_completed": true,
			"adult_rescue_count": 0,
			"parent_trust_score": 4,
			"frustration": {"rage_taps": 0, "abandoned": false},
		},
		{
			"age_band": "6-8",
			"time_to_first_fun_seconds": 150,
		},
		"not-a-dictionary",
	]

	var report: Dictionary = service.build_monthly_report("2026-04", sessions)
	_assert_eq(report.get("sample_size", 0), 2, "Only valid 6-8 sessions should be counted")


func _test_mvp_benchmark_failure_flag() -> void:
	var service = ServiceScn.new()
	var sessions: Array = [
		{
			"session_id": "f-1",
			"age_band": "6-8",
			"time_to_first_fun_seconds": 100,
			"first_playable_loop_seconds": 910,
			"loop_completed": true,
			"adult_rescue_count": 1,
			"parent_trust_score": 3,
			"frustration": {"rage_taps": 4, "abandoned": false},
		},
		{
			"session_id": "f-2",
			"age_band": "6-8",
			"time_to_first_fun_seconds": 120,
			"first_playable_loop_seconds": 930,
			"loop_completed": true,
			"adult_rescue_count": 0,
			"parent_trust_score": 3,
			"frustration": {"rage_taps": 0, "abandoned": false},
		},
		{
			"session_id": "f-3",
			"age_band": "6-8",
			"time_to_first_fun_seconds": 130,
			"first_playable_loop_seconds": 700,
			"loop_completed": true,
			"adult_rescue_count": 0,
			"parent_trust_score": 4,
			"frustration": {"rage_taps": 1, "abandoned": false},
		},
		{
			"session_id": "f-4",
			"age_band": "6-8",
			"time_to_first_fun_seconds": 140,
			"first_playable_loop_seconds": 600,
			"loop_completed": true,
			"adult_rescue_count": 0,
			"parent_trust_score": 4,
			"frustration": {"rage_taps": 0, "abandoned": false},
		},
	]

	var report: Dictionary = service.build_monthly_report("2026-05", sessions)
	var benchmarks: Dictionary = report.get("benchmarks", {})
	_assert_false(
		bool(benchmarks.get("mvp_first_playable_loop_within_15m_pass", true)),
		"Benchmark should fail when completion rate is below 0.8"
	)
