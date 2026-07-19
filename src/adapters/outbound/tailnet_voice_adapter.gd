class_name TailnetVoiceAdapter
extends VoicePromptPort

const _API_HOST := "https://voice-agent.tail5d39b4.ts.net"
const _CACHE_DIR := "user://tailnet_voice_cache"
const _REQUEST_TIMEOUT_SECONDS := 10.0

const REF_AUDIO_PATHS := {
	"npc_explorer": "res://data/audio/voice/adventure_olek_greeting.mp3",
	"npc_pirate": "res://data/audio/voice/adventure_pablo_greeting.mp3",
	"npc_parrot": "res://data/audio/voice/adventure_pestka_greeting.mp3",
}

var _host: Node = null
var _player: AudioStreamPlayer = null
var _eleven_labs: ElevenLabsVoicePromptAdapter = null
var _active_voice_id: String = ""
var _verified_voices: Dictionary = {}
var _active_http: HTTPRequest = null

# Queue for speak requests
var _speak_queue: Array[Dictionary] = []
var _is_speaking: bool = false


func setup(host: Node, eleven_key: String = "", eleven_voice: String = "") -> TailnetVoiceAdapter:
	_host = host
	if _host != null:
		_player = AudioStreamPlayer.new()
		_player.bus = "Voice"
		_host.add_child(_player)
		_player.finished.connect(_on_playback_finished)
		_ensure_cache_dir()

		# Setup fallback ElevenLabs adapter
		_eleven_labs = ElevenLabsVoicePromptAdapter.new().setup(host, eleven_key, eleven_voice)
		if _eleven_labs != null:
			_eleven_labs.playback_started.connect(func(t: String, r: int) -> void: playback_started.emit(t, r))
			_eleven_labs.playback_finished.connect(func(t: String, r: int) -> void: playback_finished.emit(t, r))
			_eleven_labs.playback_skipped.connect(func(t: String, r: int) -> void: playback_skipped.emit(t, r))

		# Eagerly check and clone voices
		_eager_check_and_clone_voices()

	return self


func is_available() -> bool:
	return true


func set_active_voice_id(voice_id: String) -> void:
	_active_voice_id = voice_id


func speak(text: String, locale: String = "pl-PL", request_id: int = 0) -> void:
	var line := text.strip_edges()
	if line.is_empty():
		return

	if _active_voice_id.is_empty() or not _verified_voices.get(_active_voice_id, false):
		# Fall back to ElevenLabs if voice is not yet verified or cloned
		if _eleven_labs != null and _eleven_labs.is_available():
			_eleven_labs.speak(line, locale, request_id)
		else:
			playback_skipped.emit(line, request_id)
		return

	_speak_queue.append({"text": line, "locale": locale, "request_id": request_id})
	_pump_queue()


func cancel() -> void:
	if _active_http != null:
		_active_http.cancel_request()
		_active_http.queue_free()
		_active_http = null
	if _player != null:
		_player.stop()
	if _eleven_labs != null:
		_eleven_labs.cancel()
	_speak_queue.clear()
	_is_speaking = false


func _pump_queue() -> void:
	if _is_speaking or _speak_queue.is_empty() or _active_http != null:
		return

	var item: Dictionary = _speak_queue.front()
	var text: String = item["text"]
	var request_id: int = item["request_id"]

	# Check cache first
	var cache_file := _cache_path(text, _active_voice_id)
	if FileAccess.file_exists(cache_file):
		_speak_queue.pop_front()
		if not _play_file(cache_file, text, request_id):
			playback_skipped.emit(text, request_id)
			_pump_queue()
		return

	_is_speaking = true

	# Call tailnet speak API
	var url := "%s/api/speak" % _API_HOST
	var headers := [
		"Content-Type: application/json",
		"Accept: application/json"
	]
	var payload := {
		"text": text,
		"voice_id": _active_voice_id
	}

	var http := HTTPRequest.new()
	_host.add_child(http)
	_active_http = http
	http.request_completed.connect(func(result: int, response_code: int, response_headers: PackedStringArray, body: PackedByteArray) -> void:
		_active_http = null
		http.queue_free()

		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			# Fallback to ElevenLabs
			_is_speaking = false
			_speak_queue.pop_front()
			if _eleven_labs != null and _eleven_labs.is_available():
				_eleven_labs.speak(text, item["locale"], request_id)
			else:
				playback_skipped.emit(text, request_id)
				_pump_queue()
			return

		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) != OK or not json.data is Dictionary:
			_is_speaking = false
			_speak_queue.pop_front()
			playback_skipped.emit(text, request_id)
			_pump_queue()
			return

		var data: Dictionary = json.data
		var audio_url: String = str(data.get("audio_url", ""))
		if audio_url.is_empty():
			_is_speaking = false
			_speak_queue.pop_front()
			playback_skipped.emit(text, request_id)
			_pump_queue()
			return
		# Server returns relative paths like "/audio/s2pro_*.wav" — resolve
		# them against the API host so HTTPRequest gets an absolute URL.
		if audio_url.begins_with("/"):
			audio_url = _API_HOST + audio_url

		# Download audio bytes
		_download_audio(audio_url, text, request_id, cache_file)
	)

	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_active_http = null
		http.queue_free()
		_is_speaking = false
		_speak_queue.pop_front()
		playback_skipped.emit(text, request_id)
		_pump_queue()


func _download_audio(audio_url: String, text: String, request_id: int, cache_file: String) -> void:
	var http := HTTPRequest.new()
	_host.add_child(http)
	_active_http = http

	http.request_completed.connect(func(result: int, response_code: int, response_headers: PackedStringArray, body: PackedByteArray) -> void:
		_active_http = null
		http.queue_free()
		_is_speaking = false
		_speak_queue.pop_front()

		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or body.is_empty():
			playback_skipped.emit(text, request_id)
			_pump_queue()
			return

		# Write to cache
		var f := FileAccess.open(cache_file, FileAccess.WRITE)
		if f != null:
			f.store_buffer(body)
			f.close()

		if not _play_bytes(body, text, request_id):
			playback_skipped.emit(text, request_id)

		_pump_queue()
	)

	var err := http.request(audio_url, [], HTTPClient.METHOD_GET)
	if err != OK:
		_active_http = null
		http.queue_free()
		_is_speaking = false
		_speak_queue.pop_front()
		playback_skipped.emit(text, request_id)
		_pump_queue()


func _play_bytes(mp3: PackedByteArray, text: String, request_id: int) -> bool:
	if _player == null:
		return false
	var stream := AudioStreamMP3.new()
	stream.data = mp3
	_player.stream = stream
	_player.play()
	playback_started.emit(text, request_id)
	return true


func _play_file(path: String, text: String, request_id: int) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var bytes := f.get_buffer(f.get_length())
	f.close()
	return _play_bytes(bytes, text, request_id)


func _on_playback_finished() -> void:
	_is_speaking = false
	playback_finished.emit("", 0)
	_pump_queue()


func _eager_check_and_clone_voices() -> void:
	var http := HTTPRequest.new()
	_host.add_child(http)
	http.request_completed.connect(func(result: int, response_code: int, response_headers: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			push_warning("TailnetVoiceAdapter: failed to fetch voices from agent")
			return

		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) != OK or not json.data is Array:
			return

		var existing_voices := {}
		for voice in json.data:
			if voice is Dictionary:
				existing_voices[str(voice.get("id", ""))] = true

		# Check and clone each missing reference voice
		for voice_id in REF_AUDIO_PATHS.keys():
			if existing_voices.has(voice_id):
				_verified_voices[voice_id] = true
			else:
				_clone_voice_on_agent(voice_id, REF_AUDIO_PATHS[voice_id])
	)

	var err := http.request("%s/api/voices" % _API_HOST, [], HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()


func _clone_voice_on_agent(voice_id: String, ref_path: String) -> void:
	if not FileAccess.file_exists(ref_path):
		push_warning("TailnetVoiceAdapter: reference audio file missing: %s" % ref_path)
		return

	var file := FileAccess.open(ref_path, FileAccess.READ)
	if file == null:
		return
	var bytes := file.get_buffer(file.get_length())
	file.close()

	var boundary := "---------------------------GodotMultipartBoundary"
	var body := PackedByteArray()
	
	# Add name field
	var name_field := "--" + boundary + "\r\n" \
		+ "Content-Disposition: form-data; name=\"name\"\r\n\r\n" \
		+ voice_id + "\r\n"
	body.append_array(name_field.to_utf8_buffer())
	
	# Add reference_audio file field
	var filename := ref_path.get_file()
	var file_header := "--" + boundary + "\r\n" \
		+ "Content-Disposition: form-data; name=\"reference_audio\"; filename=\"" + filename + "\"\r\n" \
		+ "Content-Type: audio/mpeg\r\n\r\n"
	body.append_array(file_header.to_utf8_buffer())
	body.append_array(bytes)
	body.append_array("\r\n".to_utf8_buffer())
	
	# Close boundary
	var close_boundary := "--" + boundary + "--\r\n"
	body.append_array(close_boundary.to_utf8_buffer())

	var headers := [
		"Content-Type: multipart/form-data; boundary=" + boundary
	]

	var http := HTTPRequest.new()
	_host.add_child(http)
	http.request_completed.connect(func(result: int, response_code: int, response_headers: PackedStringArray, response_body: PackedByteArray) -> void:
		http.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			_verified_voices[voice_id] = true
			print("[TailnetVoiceAdapter] voice cloned successfully: %s" % voice_id)
		else:
			push_warning("TailnetVoiceAdapter: failed to clone voice %s: code=%d" % [voice_id, response_code])
	)

	var err := http.request_raw("%s/api/clone_voice" % _API_HOST, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()


func _cache_path(text: String, voice_id: String) -> String:
	return "%s/%s.mp3" % [_CACHE_DIR, ("%s_%s" % [voice_id, text]).sha256_text()]


func _ensure_cache_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_CACHE_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_CACHE_DIR))
