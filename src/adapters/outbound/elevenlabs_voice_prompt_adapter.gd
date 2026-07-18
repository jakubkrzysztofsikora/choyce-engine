## Real ElevenLabs TTS behind the VoicePromptPort contract. Fire-and-forget
## spoken lines (NPC dialogue, onboarding). Short static lines are cached to
## disk so a line is only synthesized once. No API key -> is_available() false
## and speak() is a silent no-op, so the game runs fine offline.
##
## Not routed through the AudioGovernanceService stub stack — this is the live
## path. Requires a Node parent (for HTTPRequest + AudioStreamPlayer), so it is
## created and add_child()-ed by the gameplay runtime, not the pure ports layer.
class_name ElevenLabsVoicePromptAdapter
extends VoicePromptPort

const _API_HOST := "https://api.elevenlabs.io"
const _MODEL := "eleven_multilingual_v2"
const _CACHE_DIR := "user://voice_cache"
## ElevenLabs default voice — a stock voice on the standard library ("Harry -
## Fierce Warrior", fits a game NPC). The multilingual_v2 model speaks Polish
## regardless of the voice's label. Overridable via ELEVENLABS_VOICE_ID; if an
## account lacks this voice the request 404s and NPCs fall back to captions.
const _DEFAULT_VOICE := "SOYHLrjzK2X1ezoPC6cr"
const _MAX_QUEUED_LINES := 12
const _REQUEST_TIMEOUT_SECONDS := 10.0


## Small state machine kept separate from the Godot HTTP/audio nodes so the
## ordering rules can be verified without a real ElevenLabs request or API key.
class VoicePlaybackQueue extends RefCounted:
	enum NextAction {
		NONE,
		PLAY_CACHED,
		SYNTHESIZE,
	}

	var _lines: Array[String] = []
	var _synthesizing_line := ""
	var _playing_line := ""
	var _capacity: int

	func _init(capacity: int = _MAX_QUEUED_LINES) -> void:
		_capacity = max(1, capacity)

	func enqueue(line: String) -> bool:
		if _lines.size() >= _capacity:
			return false
		_lines.append(line)
		return true

	func next_action(head_is_cached: bool) -> NextAction:
		if is_busy() or _lines.is_empty():
			return NextAction.NONE
		if head_is_cached:
			_playing_line = _lines.front()
			return NextAction.PLAY_CACHED
		_synthesizing_line = _lines.front()
		return NextAction.SYNTHESIZE

	func finish_synthesis(succeeded: bool) -> bool:
		if _synthesizing_line.is_empty():
			return false
		var was_head: bool = not _lines.is_empty() and _lines.front() == _synthesizing_line
		var line := _synthesizing_line
		_synthesizing_line = ""
		if not was_head:
			return false
		if succeeded:
			_playing_line = line
		else:
			_lines.pop_front()
		return true

	func finish_playback() -> bool:
		if _playing_line.is_empty():
			return false
		var was_head: bool = not _lines.is_empty() and _lines.front() == _playing_line
		_playing_line = ""
		if was_head:
			_lines.pop_front()
		return was_head

	func cancel() -> void:
		_lines.clear()
		_synthesizing_line = ""
		_playing_line = ""

	func is_busy() -> bool:
		return not _synthesizing_line.is_empty() or not _playing_line.is_empty()

	func front_line() -> String:
		return "" if _lines.is_empty() else _lines.front()

	func queued_lines() -> PackedStringArray:
		return PackedStringArray(_lines)

var _api_key: String = ""
var _voice_id: String = _DEFAULT_VOICE
var _host: Node = null
var _http: HTTPRequest = null
var _player: AudioStreamPlayer = null
var _queue := VoicePlaybackQueue.new()


## host: a Node in the tree that will parent the HTTPRequest + AudioStreamPlayer.
func setup(host: Node, api_key: String = "", voice_id: String = "") -> ElevenLabsVoicePromptAdapter:
	_host = host
	_api_key = api_key.strip_edges()
	if not voice_id.strip_edges().is_empty():
		_voice_id = voice_id.strip_edges()
	if _host != null and is_available():
		_http = HTTPRequest.new()
		# A hung DNS/TLS/HTTP request must complete as a failure so queued NPC
		# dialogue can advance to its caption fallback.
		_http.timeout = _REQUEST_TIMEOUT_SECONDS
		_host.add_child(_http)
		_http.request_completed.connect(_on_request_completed)
		_player = AudioStreamPlayer.new()
		_player.bus = "Master"
		_host.add_child(_player)
		_player.finished.connect(_on_playback_finished)
		_ensure_cache_dir()
	return self


func is_available() -> bool:
	return not _api_key.is_empty()


func speak(text: String, _locale: String = "pl-PL") -> void:
	if not is_available() or _http == null:
		return
	var line := text.strip_edges()
	if line.is_empty():
		return
	if not _queue.enqueue(line):
		push_warning("ElevenLabsVoicePrompt: queue full; dropping newest line")
		playback_skipped.emit(line)
		return
	_pump_queue()


func _pump_queue() -> void:
	if _http == null or _player == null or _queue.is_busy():
		return
	var line := _queue.front_line()
	if line.is_empty():
		return
	var path := _cache_path(line)
	var action := _queue.next_action(FileAccess.file_exists(path))
	if action == VoicePlaybackQueue.NextAction.PLAY_CACHED:
		if not _play_file(path):
			# A corrupt or unreadable cache entry must not block later dialogue.
			var skipped_line := _queue.front_line()
			_queue.finish_playback()
			if not skipped_line.is_empty():
				playback_skipped.emit(skipped_line)
			_pump_queue()
		return
	if action != VoicePlaybackQueue.NextAction.SYNTHESIZE:
		return
	var url := "%s/v1/text-to-speech/%s" % [_API_HOST, _voice_id]
	var headers := [
		"xi-api-key: %s" % _api_key,
		"Content-Type: application/json",
		"Accept: audio/mpeg",
	]
	var body := JSON.stringify({
		"text": line,
		"model_id": _MODEL,
		"voice_settings": {"stability": 0.5, "similarity_boost": 0.75},
	})
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_warning("ElevenLabsVoicePrompt: could not start TTS request error=%d" % err)
		var skipped_line := _queue.front_line()
		_queue.finish_synthesis(false)
		if not skipped_line.is_empty():
			playback_skipped.emit(skipped_line)
		_pump_queue()


func cancel() -> void:
	if _http != null:
		_http.cancel_request()
	if _player != null:
		_player.stop()
	_queue.cancel()


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		# result != 0 is a transport-level failure (e.g. 3 = can't connect,
		# usually TLS/cert issues in a headless/sandbox context). NPCs fall
		# back to captions; a real desktop run with a system cert store connects.
		push_warning("ElevenLabsVoicePrompt: transport failure result=%d (captions only)" % result)
		var skipped_line := _queue.front_line()
		_queue.finish_synthesis(false)
		if not skipped_line.is_empty():
			playback_skipped.emit(skipped_line)
		_pump_queue()
		return
	if code != 200 or body.is_empty():
		push_warning("ElevenLabsVoicePrompt: TTS failed http=%d" % code)
		var skipped_line := _queue.front_line()
		_queue.finish_synthesis(false)
		if not skipped_line.is_empty():
			playback_skipped.emit(skipped_line)
		_pump_queue()
		return
	# Persist so this line never costs a second request.
	var line := _queue.front_line()
	var path := _cache_path(line)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_buffer(body)
		f.close()
	if not _queue.finish_synthesis(true) or not _play_bytes(body):
		var skipped_line := _queue.front_line()
		_queue.finish_playback()
		if not skipped_line.is_empty():
			playback_skipped.emit(skipped_line)
		_pump_queue()


func _on_playback_finished() -> void:
	var finished_line := _queue.front_line()
	_queue.finish_playback()
	if not finished_line.is_empty():
		playback_finished.emit(finished_line)
	_pump_queue()


func _play_bytes(mp3: PackedByteArray) -> bool:
	if _player == null:
		return false
	var stream := AudioStreamMP3.new()
	stream.data = mp3
	_player.stream = stream
	_player.play()
	playback_started.emit(_queue.front_line())
	return true


func _play_file(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var bytes := f.get_buffer(f.get_length())
	f.close()
	return _play_bytes(bytes)


func _cache_path(line: String) -> String:
	return "%s/%s.mp3" % [_CACHE_DIR, ("%s_%s" % [_voice_id, line]).sha256_text()]


func _ensure_cache_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_CACHE_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_CACHE_DIR))
