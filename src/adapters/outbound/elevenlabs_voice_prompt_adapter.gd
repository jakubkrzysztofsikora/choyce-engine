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
## ElevenLabs public multilingual voice — works for Polish. Overridable via env.
const _DEFAULT_VOICE := "onwK4e9ZLuTAKqWW03F"   # "Daniel"

var _api_key: String = ""
var _voice_id: String = _DEFAULT_VOICE
var _host: Node = null
var _http: HTTPRequest = null
var _player: AudioStreamPlayer = null
var _pending_text: String = ""


## host: a Node in the tree that will parent the HTTPRequest + AudioStreamPlayer.
func setup(host: Node, api_key: String = "", voice_id: String = "") -> ElevenLabsVoicePromptAdapter:
	_host = host
	_api_key = api_key.strip_edges()
	if not voice_id.strip_edges().is_empty():
		_voice_id = voice_id.strip_edges()
	if _host != null and is_available():
		_http = HTTPRequest.new()
		_host.add_child(_http)
		_http.request_completed.connect(_on_request_completed)
		_player = AudioStreamPlayer.new()
		_player.bus = "Master"
		_host.add_child(_player)
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
	# Cache hit: play straight from disk, no network.
	var path := _cache_path(line)
	if FileAccess.file_exists(path):
		_play_file(path)
		return
	# One in-flight request at a time (fire-and-forget UI speech).
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_pending_text = line
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
		_pending_text = ""


func cancel() -> void:
	if _http != null:
		_http.cancel_request()
	if _player != null:
		_player.stop()
	_pending_text = ""


func _on_request_completed(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var line := _pending_text
	_pending_text = ""
	if code != 200 or body.is_empty():
		push_warning("ElevenLabsVoicePrompt: TTS failed code=%d" % code)
		return
	# Persist so this line never costs a second request.
	var path := _cache_path(line)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_buffer(body)
		f.close()
	_play_bytes(body)


func _play_bytes(mp3: PackedByteArray) -> void:
	if _player == null:
		return
	var stream := AudioStreamMP3.new()
	stream.data = mp3
	_player.stream = stream
	_player.play()


func _play_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var bytes := f.get_buffer(f.get_length())
	f.close()
	_play_bytes(bytes)


func _cache_path(line: String) -> String:
	return "%s/%s.mp3" % [_CACHE_DIR, ("%s_%s" % [_voice_id, line]).sha256_text()]


func _ensure_cache_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_CACHE_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_CACHE_DIR))
