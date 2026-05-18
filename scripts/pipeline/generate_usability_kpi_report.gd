extends SceneTree

## Run the Usability KPI reporting pipeline against a set of JSONL log files.
## Usage: godot --headless --script scripts/pipeline/generate_usability_kpi_report.gd <log_dir> <month_id>

func _init() -> void:
	var args := OS.get_cmdline_args()
	# Args: [script path, log_dir, month_id, (optional) output_file]
	# But when running --script, args after script are usually passed.
	# Actually, OS.get_cmdline_args() returns ALL args including flags.
	# We need to find the script and take subsequent args.
	
	var script_idx := -1
	for i in range(args.size()):
		if args[i].ends_with("generate_usability_kpi_report.gd"):
			script_idx = i
			break
			
	if script_idx == -1 or script_idx + 1 >= args.size():
		print_json({"error": "Usage: <script> <log_dir> [month_id]"})
		quit(1)
		return
		
	var log_dir := args[script_idx + 1]
	var month_id := ""
	if script_idx + 2 < args.size():
		month_id = args[script_idx + 2]
		
	var sessions := _parse_logs(log_dir)
	var reporter = UsabilityKPIReportingService.new()
	var report = reporter.build_monthly_report(month_id, sessions)
	
	print_json(report)
	quit(0)

func _parse_logs(dir_path: String) -> Array:
	var sessions: Dictionary = {}
	var files := _list_files(dir_path)
	
	for file_path in files:
		if not file_path.ends_with(".jsonl"):
			continue
			
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			continue
			
		while not file.eof_reached():
			var line := file.get_line().strip_edges()
			if line.is_empty():
				continue
				
			var event = JSON.parse_string(line)
			if event == null or not (event is Dictionary):
				continue
				
			_process_event(sessions, event)
			
	return sessions.values()

func _list_files(path: String) -> Array:
	var files: Array = []
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				files.append(path.path_join(file_name))
			file_name = dir.get_next()
	return files

func _process_event(sessions: Dictionary, event: Dictionary) -> void:
	var name = event.get("event_name", "")
	var props = event.get("properties", {})
	if not (props is Dictionary):
		return
		
	var session_id = props.get("session_id", "")
	if session_id.is_empty():
		return
		
	if not sessions.has(session_id):
		sessions[session_id] = {
			"session_id": session_id,
			"age_band": props.get("age_band", ""),
			"time_to_first_fun_seconds": 0.0,
			"first_playable_loop_seconds": 0.0,
			"loop_completed": false,
			"adult_rescue_count": 0,
			"parent_trust_score": 0.0,
			"frustration": {"rage_taps": 0, "abandoned": false}
		}
		
	var session: Dictionary = sessions[session_id]
	
	match name:
		"usability_session_start":
			session["age_band"] = props.get("age_band", session["age_band"])
			
		"usability_first_fun":
			session["time_to_first_fun_seconds"] = float(props.get("duration_seconds", 0.0))
			
		"usability_loop_complete":
			session["loop_completed"] = true
			session["first_playable_loop_seconds"] = float(props.get("duration_seconds", 0.0))
			
		"usability_adult_rescue":
			session["adult_rescue_count"] = int(props.get("count", 0))
			
		"usability_frustration":
			var stats = props.get("stats", {})
			if stats is Dictionary:
				session["frustration"] = stats
				
		"usability_session_end":
			session["parent_trust_score"] = float(props.get("parent_trust_score", 0.0))
			# Update final stats if available in end event
			if props.has("duration_seconds"):
				session["duration_seconds"] = float(props["duration_seconds"])
			if props.has("time_to_first_fun_seconds") and session["time_to_first_fun_seconds"] == 0.0:
				session["time_to_first_fun_seconds"] = float(props["time_to_first_fun_seconds"])
			if props.has("adult_rescue_count"):
				session["adult_rescue_count"] = int(props["adult_rescue_count"])
			if props.has("frustration"):
				session["frustration"] = props["frustration"]

func print_json(data: Variant) -> void:
	print(JSON.stringify(data))
