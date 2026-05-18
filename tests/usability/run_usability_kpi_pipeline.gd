extends SceneTree

const FIXTURE_PATH := "res://data/usability/monthly_playtest_fixture.json"
const REPORT_PATH := "user://reports/usability/monthly_kpi_report.json"

var _failures: Array[String] = []


func _init() -> void:
	var payload := _load_fixture()
	if payload.is_empty():
		quit(1)
		return

	var sessions_variant: Variant = payload.get("sessions", [])
	if not (sessions_variant is Array):
		print("[FAIL] Usability fixture invalid: sessions must be an array")
		quit(1)
		return
	var sessions: Array = sessions_variant

	var month_id := str(payload.get("month_id", "")).strip_edges()
	var service := UsabilityKPIReportingService.new()
	var report := service.build_monthly_report(month_id, sessions)
	report["source_fixture"] = FIXTURE_PATH

	_validate_report(report)
	_write_report(report)

	print("USABILITY_KPI_REPORT_JSON=%s" % JSON.stringify(report))

	if _failures.is_empty():
		print("Usability KPI pipeline passed.")
		quit(0)
		return

	for failure in _failures:
		print("[FAIL] %s" % failure)
	quit(1)


func _load_fixture() -> Dictionary:
	if not FileAccess.file_exists(FIXTURE_PATH):
		print("[FAIL] Missing usability fixture: %s" % FIXTURE_PATH)
		return {}

	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if file == null:
		print("[FAIL] Failed to open usability fixture: %s" % FIXTURE_PATH)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		print("[FAIL] Usability fixture must be a dictionary")
		return {}

	return parsed


func _validate_report(report: Dictionary) -> void:
	var sample_size := int(report.get("sample_size", 0))
	if sample_size <= 0:
		_failures.append("Usability KPI report has zero eligible sessions")

	var kpis_variant: Variant = report.get("kpis", {})
	if not (kpis_variant is Dictionary):
		_failures.append("Usability KPI report missing kpis dictionary")
		return
	var kpis: Dictionary = kpis_variant

	for key in [
		"time_to_first_fun_median_seconds",
		"completion_without_adult_rescue_rate",
		"adult_rescue_rate",
		"parent_trust_score_avg",
		"frustration_signal_rate",
		"first_playable_loop_within_15m_rate",
	]:
		if not kpis.has(key):
			_failures.append("Usability KPI report missing '%s'" % key)

	var benchmarks_variant: Variant = report.get("benchmarks", {})
	if not (benchmarks_variant is Dictionary):
		_failures.append("Usability KPI report missing benchmarks dictionary")
		return
	var benchmarks: Dictionary = benchmarks_variant

	if not bool(benchmarks.get("mvp_first_playable_loop_within_15m_pass", false)):
		_failures.append("MVP usability benchmark did not pass for fixture data")


func _write_report(report: Dictionary) -> void:
	var absolute_dir := ProjectSettings.globalize_path(REPORT_PATH.get_base_dir())
	DirAccess.make_dir_recursive_absolute(absolute_dir)

	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		_failures.append("Failed to write KPI report artifact to %s" % REPORT_PATH)
		return

	file.store_string(JSON.stringify(report, "\t"))
