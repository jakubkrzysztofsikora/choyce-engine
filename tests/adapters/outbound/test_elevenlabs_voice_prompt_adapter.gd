## Network-free regression tests for the ElevenLabs prompt playback scheduler.
extends SceneTree

const AdapterScript = preload("res://src/adapters/outbound/elevenlabs_voice_prompt_adapter.gd")

var _exit_code := 0


func _init() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_exit_code = 1


func _assert_lines(actual: PackedStringArray, expected: PackedStringArray, message: String) -> void:
	_assert(actual == expected, "%s (got %s)" % [message, actual])


func _run() -> void:
	var queue := AdapterScript.VoicePlaybackQueue.new(3)
	_assert(queue.enqueue("cached-first"), "first line enters queue")
	_assert(queue.enqueue("synth-second"), "second line enters queue")
	_assert(queue.enqueue("cached-third"), "third line enters queue")
	_assert(not queue.enqueue("dropped-fourth"), "bounded queue drops newest line when full")
	_assert_lines(queue.queued_lines(), PackedStringArray(["cached-first", "synth-second", "cached-third"]), "FIFO order is retained")

	_assert(queue.next_action(true) == queue.NextAction.PLAY_CACHED, "cached head begins playback")
	_assert(queue.next_action(false) == queue.NextAction.NONE, "active cached playback cannot be interrupted")
	_assert(queue.finish_playback(), "finished cached playback removes only the head")
	_assert(queue.next_action(false) == queue.NextAction.SYNTHESIZE, "uncached second line synthesizes after cached first")
	_assert(queue.next_action(true) == queue.NextAction.NONE, "only one synthesis may be active")
	_assert(queue.finish_synthesis(true), "successful synthesis advances to playback")
	_assert(queue.next_action(true) == queue.NextAction.NONE, "synthesized line plays before later cache hit")
	_assert(queue.finish_playback(), "synthesized playback removes second line")
	_assert(queue.next_action(true) == queue.NextAction.PLAY_CACHED, "later cached line plays only after synthesized line")
	_assert(queue.finish_playback(), "third playback finishes")
	_assert_lines(queue.queued_lines(), PackedStringArray(), "queue drains in FIFO order")

	var failing_queue := AdapterScript.VoicePlaybackQueue.new()
	failing_queue.enqueue("request-fails")
	failing_queue.enqueue("next-line")
	_assert(failing_queue.next_action(false) == failing_queue.NextAction.SYNTHESIZE, "failure case starts the head synthesis")
	_assert(failing_queue.finish_synthesis(false), "failed synthesis releases the failed head")
	_assert_lines(failing_queue.queued_lines(), PackedStringArray(["next-line"]), "failure advances to the next queued line")
	_assert(failing_queue.next_action(false) == failing_queue.NextAction.SYNTHESIZE, "next queued line can synthesize after failure")

	# A cancelled HTTPRequest can still finish in a later frame. Its callback
	# must not consume or corrupt a replacement line that has already started.
	var gate := AdapterScript.RequestGenerationGate.new()
	var stale_generation := gate.begin()
	gate.invalidate()
	var current_generation := gate.begin()
	_assert(not gate.accepts(stale_generation) and gate.accepts(current_generation),
		"cancelled transport generation cannot be mistaken for the replacement request")
	var callback_adapter := AdapterScript.new()
	callback_adapter._request_generation = gate
	var active_request := HTTPRequest.new()
	callback_adapter._active_http = active_request
	callback_adapter._queue.enqueue("replacement-line", 42)
	callback_adapter._queue.next_action(false)
	callback_adapter._on_request_completed(
		HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray(), stale_generation, HTTPRequest.new())
	_assert(callback_adapter._active_http == active_request \
		and callback_adapter._queue.queued_lines() == PackedStringArray(["replacement-line"]),
		"late cancelled callback leaves the replacement dialogue queue untouched")
	active_request.free()

	var unavailable := AdapterScript.new()
	unavailable.speak("offline no-op")
	_assert_lines(unavailable._queue.queued_lines(), PackedStringArray(), "unavailable adapter remains a silent no-op")
	quit(_exit_code)
