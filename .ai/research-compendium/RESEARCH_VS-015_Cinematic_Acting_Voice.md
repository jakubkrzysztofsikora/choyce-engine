# VS-015: Cinematic Acting & Voice - Deep Research Compendium

**Status**: in_progress  
**Specialty**: cinematic-audio  
**Owner**: codex  
**Cross-review**: claude  
**Priority**: HIGH  
**Last Updated**: 2026-07-18

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Current Implementation Status](#current-implementation-status)
3. [ElevenLabs TTS Integration](#elevenlabs-tts-integration)
4. [Voice Selection & Characterization](#voice-selection--characterization)
5. [Voice Queue & Serialization System](#voice-queue--serialization-system)
6. [Audio Spatialization](#audio-spatialization)
7. [Caption Synchronization](#caption-synchronization)
8. [Mixing & Level Balancing](#mixing--level-balancing)
9. [Code Samples & Implementation Patterns](#code-samples--implementation-patterns)
10. [Asset Sources & Voice Management](#asset-sources--voice-management)
11. [Best Practices](#best-practices)
12. [Testing & Validation Checklist](#testing--validation-checklist)
13. [Learning Resources](#learning-resources)

---

## Task Overview

### Objective

Implement a production-quality cinematic audio system with distinct character voices, serialized dialogue, synchronized captions, and intelligible audio levels across all platforms (including laptop speakers).

### Key Requirements

- **Ziemek & Gniewko**: Distinct masculine youthful voices using ElevenLabs
- **No Overlap**: Voice lines must play sequentially without interruption
- **Captions**: Every spoken line must have matching, synchronized subtitles
- **Audio Balance**: Physical impacts, whooshes, footsteps, music, and voice all intelligible on laptop speakers
- **Serialization**: Voice lines queue and play in order without gaps or overlaps

### Acceptance Criteria (from backlog.yaml)

- [ ] Ziemek and Gniewko use distinct masculine youthful ElevenLabs voices with emotional delivery
- [ ] Voice lines are serialized and never overlap or mute each other
- [ ] Character captions match spoken lines and finish before launcher handoff
- [ ] Physical impact, whoosh, footstep, music, and voice levels are intelligible on laptop speakers

### Dependencies

- VS-012 (Modern Game UI - for caption display)
- VS-006 (Audio Visual Accessibility - for caption system foundation)
- VS-014 (Modern Game UI - for clean presentation)

---

## Current Implementation Status

### Existing Code & Evidence

From backlog.yaml:

```
├── scripts/audio/
│   └── generate_eleven_assets.py  # Voice generation script
├── src/adapters/inbound/shared/audio/
│   ├── bus_setup.gd               # Audio bus configuration
│   ├── bus_setup.tscn             # Bus setup scene
│   └── audio_bank.gd             # Audio playing system
├── src/adapters/inbound/scenes/launcher/
│   └── launcher_overlay.gd        # Launcher with voice triggers
```

### Current Gaps

1. **ElevenLabs Integration**: Need plugin setup or custom HTTP client
2. **Voice Selection**: Need specific Polish masculine youthful voice IDs (Ziemek, Gniewko)
3. **Queue System**: Need robust voice queue preventing overlap
4. **Caption Sync**: Need subtitle timing synchronized with voice playback
5. **Spatial Audio**: Need 3D voice positioning for characters
6. **Mixing Validation**: Need level testing on laptop speakers

---

## ElevenLabs TTS Integration

### Official ElevenLabs API

**API Documentation**: [https://elevenlabs.io/docs/api-reference](https://elevenlabs.io/docs/api-reference)

#### Authentication

```gdscript
# Get API key from: https://elevenlabs.io/app/api/api-keys
const API_KEY = "your-elevenlabs-api-key"
const API_URL = "https://api.elevenlabs.io/v1"
```

#### API Endpoints

| Endpoint | Purpose | HTTP Method |
|----------|---------|-------------|
| `/text-to-speech/{voice_id}` | Generate speech from text | POST |
| `/voices` | List available voices | GET |
| `/voices/search` | Search for voices with filters | GET |
| `/user` | Get user information | GET |

### Method 1: Using Official Godot Plugin

**Plugin**: [Wiechciu/eleven-labs](https://github.com/Wiechciu/eleven-labs)

**Features**:
- Native Godot 4 integration
- Voice browser and selector
- Direct TTS generation
- Streaming support

**Installation**:
1. Download plugin from GitHub
2. Place in `addons/` folder
3. Enable in Project Settings > Plugins
4. Enter API key in plugin settings

**Usage Example**:
```gdscript
# With plugin enabled, use the provided nodes
export(ElevenLabsTTS) var eleven_tts

func generate_speech(text: String, voice_id: String) -> void:
    eleven_tts.text = text
    eleven_tts.voice_id = voice_id
    eleven_tts.generate()
    
    # Connect to finished signal
    eleven_tts.finished.connect(_on_tts_finished)

func _on_tts_finished(audio_data: PackedByteArray) -> void:
    var audio_stream := WAVStream.new()
    audio_stream.data = audio_data
    audio_stream.loop_mode = AudioStream.WAVE_LOOP_NONE
    
    var player := AudioStreamPlayer.new()
    player.stream = audio_stream
    player.bus = "Voice"
    add_child(player)
    player.play()
```

### Method 2: Custom HTTPRequest Implementation

```gdscript
# src/adapters/outbound/elevenlabs_tts_adapter.gd

class_name ElevenLabsTTSAdapter
extends RefCounted

const API_KEY := ProjectSettings.get_setting("elevenlabs/api_key")
const API_BASE := "https://api.elevenlabs.io/v1"

# Voice cache
var voice_cache: Dictionary = {}

# Generation settings
@export var default_voice_id: String = ""
@export var default_model: String = "eleven_multilingual_v2"
@export var default_stability: float = 0.5
@export var default_similarity_boost: float = 0.5
@export var default_style: float = 0.0
@export var default_use_speaker_boost: bool = true

func initialize() -> void:
    _load_voice_cache()

# Generate TTS and return audio stream
func generate_tts(text: String, voice_id: String = "", callback: Callable = null) -> void:
    var actual_voice := voice_id if voice_id else default_voice_id
    
    var http := HTTPRequest.new()
    add_child(http)
    
    var headers := [
        "xi-api-key: %s" % API_KEY,
        "Content-Type: application/json"
    ]
    
    var body := JSON.new()
    body["text"] = text
    body["model_id"] = default_model
    body["voice_settings"] = {
        "stability": default_stability,
        "similarity_boost": default_similarity_boost,
        "style": default_style,
        "use_speaker_boost": default_use_speaker_boost
    }
    
    var url := "%s/text-to-speech/%s" % [API_BASE, actual_voice]
    
    http.request(url, headers, true, HTTPClient.METHOD_POST, body.get_data())
    
    if callback:
        http.request_completed.connect(_on_request_complete.bind(callback))

func _on_request_complete(result: int, response_code: int, headers: Array, body: PackedByteArray, callback: Callable) -> void:
    if response_code == 200:
        var audio_stream := WAVStream.new()
        audio_stream.data = body
        audio_stream.loop_mode = AudioStream.WAVE_LOOP_NONE
        callback.call(audio_stream)
    else:
        var error_data := JSON.parse_string(body.get_string_from_utf8())
        printerr("ElevenLabs API Error: %s" % error_data.get("detail", "Unknown error"))
        callback.call(null)
    
    # Cleanup
    queue_free()

# List available voices
func list_voices() -> Array:
    var http := HTTPRequest.new()
    add_child(http)
    
    var headers := ["xi-api-key: %s" % API_KEY]
    var url := "%s/voices" % API_BASE
    
    var err := http.request(url, headers)
    if err != OK:
        return []
    
    # Wait for response
    var response := http.get_response_body()
    return JSON.parse_string(response.get_string_from_utf8()).result("voices", [])

# Search for voices by language and gender
func search_voices(language: String = "pl", gender: String = "male", age: String = "young") -> Array:
    var http := HTTPRequest.new()
    add_child(http)
    
    var headers := ["xi-api-key: %s" % API_KEY]
    var url := "%s/voices/search?language=%s&gender=%s&age=%s" % [API_BASE, language, gender, age]
    
    var err := http.request(url, headers)
    if err != OK:
        return []
    
    var response := http.get_response_body()
    return JSON.parse_string(response.get_string_from_utf8()).result("voices", [])
```

### Method 3: Pre-generated Audio Assets

For production stability (recommended for VS-015):

```python
# scripts/audio/generate_eleven_assets.py
import os
import json
import requests
from pathlib import Path

API_KEY = os.environ.get("ELEVENLABS_API_KEY")
API_BASE = "https://api.elevenlabs.io/v1"

VOICE_MAP = {
    "ziemek": "voice_id_here",
    "gniewko": "voice_id_here"
}

OUTPUT_DIR = Path("res://assets/audio/voice")

# Load dialogue lines from JSON
def load_dialogue_lines(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)

# Generate TTS for a line
def generate_tts(text, voice_id, filename):
    url = f"{API_BASE}/text-to-speech/{voice_id}"
    headers = {
        "xi-api-key": API_KEY,
        "Content-Type": "application/json"
    }
    data = {
        "text": text,
        "model_id": "eleven_multilingual_v2",
        "voice_settings": {
            "stability": 0.5,
            "similarity_boost": 0.5,
            "style": 0.0,
            "use_speaker_boost": True
        }
    }
    
    response = requests.post(url, headers=headers, json=data)
    
    if response.status_code == 200:
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        with open(OUTPUT_DIR / filename, 'wb') as f:
            f.write(response.content)
        return True
    else:
        print(f"Error generating {filename}: {response.text}")
        return False

# Generate all voice assets
def generate_all_assets():
    lines = load_dialogue_lines("data/dialogue/ziemek_gniewko.json")
    
    for line in lines:
        character = line["character"]
        text = line["text"]
        voice_id = VOICE_MAP[character]
        filename = f"{character}_{line['id']}.wav"
        
        generate_tts(text, voice_id, filename)
        print(f"Generated: {filename}")

if __name__ == "__main__":
    generate_all_assets()
```

---

## Voice Selection & Characterization

### Polish Masculine Youthful Voices (ElevenLabs)

Based on research, these voices are available:

#### Primary Candidates

| Voice Name | Voice ID | Age | Gender | Style | Notes |
|------------|----------|-----|--------|-------|-------|
| Wojciech | `S1...` | Young Adult | Male | Deep, Intimate | Great for storytelling, slightly intimate tone |
| Kamil | `S1...` | Young | Male | Conversational, Friendly | Warm, youthful, call-center style |
| Konwersacyjny Kamil | `S1...` | Young | Male | Conversational | Specifically optimized for dialogue |
| Adam | `S1...` | Young Adult | Male | Warm, Calm | Versatile, neutral accent |
| Damian PL | `S1JKkpuAQNsowB8ZvKRO` | Middle-aged | Male | Standard | May work for slightly older characters |

#### Recommended Assignment

For **Ziemek** (Primary Guide):
- **Voice**: Wojciech or Konwersacyjny Kamil
- **Character**: Warm, friendly, slightly older brother figure
- **Role**: Main guide, explains game mechanics
- **Tone**: Helpful, patient, encouraging

For **Gniewko** (Secondary Character):
- **Voice**: Adam or Kamil
- **Character**: More energetic, youthful
- **Role**: Comedic relief, action-oriented
- **Tone**: Excited, adventurous

### Voice Customization Parameters

ElevenLabs provides fine-grained control over voice generation:

```gdscript
# Voice settings for emotional delivery
var voice_settings := {
    "stability": 0.5,        # 0.0-1.0, lower = more varied
    "similarity_boost": 0.5, # 0.0-1.0, higher = more consistent with voice
    "style": 0.0,           # 0.0-1.0, higher = more expressive
    "use_speaker_boost": true # Enable voice model fine-tuning
}

# Emotional presets
var EMOTION_PRESETS := {
    "neutral": {"stability": 0.7, "similarity_boost": 0.7, "style": 0.0},
    "happy": {"stability": 0.5, "similarity_boost": 0.5, "style": 0.3},
    "angry": {"stability": 0.6, "similarity_boost": 0.6, "style": 0.4},
    "sad": {"stability": 0.8, "similarity_boost": 0.8, "style": 0.1},
    "excited": {"stability": 0.4, "similarity_boost": 0.4, "style": 0.5},
}
```

### Getting Voice IDs

To get the exact voice IDs for Polish masculine youthful voices:

1. **API Method**:
```bash
curl -X GET "https://api.elevenlabs.io/v1/voices/search?language=pl&gender=male&age=young" \
  -H "xi-api-key: YOUR_API_KEY"
```

2. **Web Interface**:
   - Go to [ElevenLabs Voice Library](https://elevenlabs.io/voice-library)
   - Filter: Language = Polish, Gender = Male, Age = Young
   - Copy the Voice ID from the desired voice

---

## Voice Queue & Serialization System

### Problem: Preventing Voice Overlap

Voice lines must play sequentially without overlapping. Solutions:

#### Solution 1: Single Voice Player with Queue

```gdscript
# src/adapters/inbound/shared/audio/voice_queue.gd

class_name VoiceQueue
extends Node

signal voice_started(character: String, line_id: String)
signal voice_finished(character: String, line_id: String)
signal voice_interrupted(character: String, line_id: String)

# Single audio player for voices
var voice_player: AudioStreamPlayer = null

# Queue of pending voice lines
var voice_queue: Array[Dictionary] = []

# Current playing voice
var current_voice: Dictionary = null

func _ready() -> void:
    voice_player = AudioStreamPlayer.new()
    voice_player.bus = "Voice"
    voice_player.finish_mode = AudioStreamPlayer.FINISH_MODE_STOP
    voice_player.finished.connect(_on_voice_finished)
    add_child(voice_player)

# Add voice line to queue
func enqueue_voice(character: String, line_id: String, audio_stream: AudioStream, caption: String = "", priority: int = 0) -> void:
    var voice_entry := {
        "character": character,
        "line_id": line_id,
        "audio_stream": audio_stream,
        "caption": caption,
        "priority": priority
    }
    
    # Insert based on priority (higher priority plays first)
    if priority > 0:
        voice_queue.insert(0, voice_entry)
    else:
        voice_queue.append(voice_entry)
    
    # If not playing, start now
    if current_voice == null and not voice_player.playing:
        _play_next_voice()

# Play next voice in queue
func _play_next_voice() -> void:
    if voice_queue.is_empty():
        current_voice = null
        return
    
    current_voice = voice_queue.pop_front()
    voice_player.stream = current_voice["audio_stream"]
    voice_player.play()
    
    voice_started.emit(current_voice["character"], current_voice["line_id"])

# Handle voice finished
func _on_voice_finished() -> void:
    if current_voice:
        voice_finished.emit(current_voice["character"], current_voice["line_id"])
        current_voice = null
    
    _play_next_voice()

# Interrupt current voice (for priority lines)
func interrupt_voice() -> void:
    if current_voice:
        voice_player.stop()
        voice_interrupted.emit(current_voice["character"], current_voice["line_id"])
        current_voice = null
        _play_next_voice()

# Clear queue
func clear_queue() -> void:
    voice_queue.clear()
    voice_player.stop()
    current_voice = null

# Is queue empty
func is_empty() -> bool:
    return voice_queue.is_empty() and current_voice == null

# Is currently playing
func is_playing() -> bool:
    return current_voice != null or voice_player.playing
```

#### Solution 2: Per-Character Voice Player

```gdscript
# src/adapters/inbound/shared/audio/character_voice_manager.gd

class_name CharacterVoiceManager
extends Node

# Voice players per character
var character_players: Dictionary = {}

# Queue per character
var character_queues: Dictionary = {}

# Currently speaking characters
var speaking_characters: Array = []

func _ready() -> void:
    # Initialize for known characters
    _initialize_character("ziemek")
    _initialize_character("gniewko")

func _initialize_character(character_name: String) -> void:
    character_queues[character_name] = []
    
    var player := AudioStreamPlayer.new()
    player.bus = "Voice"
    player.finish_mode = AudioStreamPlayer.FINISH_MODE_STOP
    player.name = "%s_VoicePlayer" % character_name
    player.finished.connect(_on_voice_finished.bind(character_name))
    add_child(player)
    character_players[character_name] = player

func enqueue_voice(character_name: String, audio_stream: AudioStream, caption: String = "") -> void:
    if not character_queues.has(character_name):
        _initialize_character(character_name)
    
    var player := character_players[character_name]
    
    # If already speaking, queue it
    if player.playing:
        character_queues[character_name].append({
            "audio_stream": audio_stream,
            "caption": caption
        })
    else:
        # Play immediately
        _play_voice(character_name, audio_stream, caption)

func _play_voice(character_name: String, audio_stream: AudioStream, caption: String) -> void:
    var player := character_players[character_name]
    player.stream = audio_stream
    player.play()
    speaking_characters.append(character_name)

func _on_voice_finished(character_name: String) -> void:
    var player := character_players[character_name]
    speaking_characters.erase(character_name)
    
    # Play next in queue
    if not character_queues[character_name].is_empty():
        var next := character_queues[character_name].pop_front()
        _play_voice(character_name, next["audio_stream"], next["caption"])

func stop_all_voices() -> void:
    for player in character_players.values():
        player.stop()
    
    speaking_characters.clear()
    for queue in character_queues.values():
        queue.clear()

func is_character_speaking(character_name: String) -> bool:
    if not character_players.has(character_name):
        return false
    return character_players[character_name].playing
```

#### Solution 3: Hybrid - Global Queue with Character Priorities

```gdscript
# src/adapters/inbound/shared/audio/dialogue_audio_manager.gd

class_name DialogueAudioManager
extends Node

# Priority levels
enum Priority { LOW, NORMAL, HIGH, URGENT }

# Queue entry
class_name QueueEntry
var character: String
var line_id: String
var audio_stream: AudioStream
var caption: String
var priority: int
var start_time: float

# Configuration
@export var max_concurrent_voices: int = 1  # Only 1 voice at a time for cinematic
@export var fade_duration: float = 0.1

# State
var voice_players: Array[AudioStreamPlayer] = []
var queue: Array[QueueEntry] = []
var active_players: int = 0

func _ready() -> void:
    # Pre-create players
    for i in range(max_concurrent_voices):
        var player := AudioStreamPlayer.new()
        player.bus = "Voice"
        player.finish_mode = AudioStreamPlayer.FINISH_MODE_STOP
        player.finished.connect(_on_player_finished)
        add_child(player)
        voice_players.append(player)

func enqueue(character: String, line_id: String, audio_stream: AudioStream, caption: String = "", priority: int = Priority.NORMAL) -> void:
    var entry := QueueEntry.new()
    entry.character = character
    entry.line_id = line_id
    entry.audio_stream = audio_stream
    entry.caption = caption
    entry.priority = priority
    entry.start_time = Time.get_unix_time_from_system()
    
    # Sort by priority (higher first, then by time)
    queue.append(entry)
    queue.sort_custom(_compare_entries)
    
    # Try to play
    _try_play_next()

func _compare_entries(a: QueueEntry, b: QueueEntry) -> bool:
    if a.priority != b.priority:
        return a.priority > b.priority
    return a.start_time < b.start_time

func _try_play_next() -> void:
    if queue.is_empty():
        return
    
    if active_players >= max_concurrent_voices:
        return
    
    var entry := queue.pop_front()
    var player := _get_free_player()
    
    if player:
        player.stream = entry.audio_stream
        player.play()
        active_players += 1
        
        # Emit caption if available
        if entry.caption:
            _show_caption(entry.character, entry.caption)

func _get_free_player() -> AudioStreamPlayer:
    for player in voice_players:
        if not player.playing:
            return player
    return null

func _on_player_finished(player: AudioStreamPlayer) -> void:
    active_players = max(0, active_players - 1)
    _try_play_next()

func _show_caption(character: String, text: String) -> void:
    # Connect to subtitle system
    var subtitle_queue := get_node("/root/World/SubtitleQueue")
    if subtitle_queue:
        subtitle_queue.enqueue(text, 0.0, character)

func stop_all() -> void:
    for player in voice_players:
        player.stop()
    active_players = 0
    queue.clear()

func is_playing() -> bool:
    return active_players > 0 or not queue.is_empty()
```

---

## Audio Spatialization

### AudioStreamPlayer3D for Character Voices

```gdscript
# src/adapters/inbound/gameplay/character_voice_3d.gd

class_name CharacterVoice3D
extends Node

# Configuration
@export var character_name: String = ""
@export var default_voice_volume: float = 0.8
@export var max_distance: float = 25.0
@export var attenuation_model: int = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE

# Audio player
var voice_player: AudioStreamPlayer3D = null

func _ready() -> void:
    voice_player = AudioStreamPlayer3D.new()
    voice_player.bus = "Voice"
    voice_player.attenuation_model = attenuation_model
    voice_player.unit_size = 5.0
    voice_player.max_distance = max_distance
    voice_player.attenuation_filter_cutoff_hz = 500.0
    voice_player.finished.connect(_on_voice_finished)
    add_child(voice_player)
    
    # Set volume
    voice_player.volume_db = linear_to_db(default_voice_volume)

func play_voice(audio_stream: AudioStream, caption: String = "") -> void:
    voice_player.stream = audio_stream
    voice_player.play()
    
    # Show caption
    if caption:
        _show_caption(character_name, caption)

func _on_voice_finished() -> void:
    # Handle voice finished
    pass

func _show_caption(character: String, text: String) -> void:
    var subtitle_queue := get_node("/root/World/SubtitleQueue")
    if subtitle_queue:
        subtitle_queue.enqueue(text, voice_player.stream.get_length() if voice_player.stream else 3.0, character)

# Update position to follow character
func update_position(target_position: Vector3) -> void:
    global_position = target_position
```

### Spatial Audio Best Practices

| Parameter | Recommended Value | Purpose |
|-----------|-------------------|---------|
| unit_size | 5.0 | Distance unit scaling |
| max_distance | 20.0-50.0 | Maximum audible distance |
| attenuation_model | INVERSE_SQUARE_DISTANCE | Realistic volume falloff |
| attenuation_filter_cutoff_hz | 500-1000 | Low-pass for distant sounds |
| doppler_tracking | ENABLED | Pitch shift with movement |

### Advanced: SpatialAudio3D Plugin

For even more realistic spatial audio:

**Plugin**: [claudehohl/SpatialAudio3D](https://github.com/claudehohl/SpatialAudio3D)

**Features**:
- Raycast-driven reverb based on geometry
- Dynamic occlusion (sounds muffled behind walls)
- Distance-based delay
- Physically-informed spatial audio

**Installation**:
1. Download from GitHub
2. Place in `addons/` folder
3. Enable in Project Settings
4. Add `SpatialAudio3D` node to scene

---

## Caption Synchronization

### Synchronized Subtitle System

```gdscript
# src/adapters/inbound/gameplay/dialogue_caption_sync.gd

class_name DialogueCaptionSync
extends Node

# Connects voice queue with subtitle display
@onready var voice_queue: VoiceQueue = get_node("../VoiceQueue")
@onready var subtitle_display: SubtitleDisplay = get_node("../SubtitleDisplay")

# Map of line_id to caption data
var caption_map: Dictionary = {}

func _ready() -> void:
    # Connect signals
    voice_queue.voice_started.connect(_on_voice_started)
    voice_queue.voice_finished.connect(_on_voice_finished)

func register_caption(line_id: String, character: String, text: String, duration: float) -> void:
    caption_map[line_id] = {
        "character": character,
        "text": text,
        "duration": duration
    }

func _on_voice_started(character: String, line_id: String) -> void:
    if caption_map.has(line_id):
        var caption_data := caption_map[line_id]
        subtitle_display.show_subtitle(
            caption_data["text"],
            caption_data["duration"],
            character
        )

func _on_voice_finished(character: String, line_id: String) -> void:
    if caption_map.has(line_id):
        subtitle_display.clear_subtitle()
```

### Caption Timing Strategies

#### Strategy 1: Audio Length-Based

```gdscript
# Use audio stream length for caption duration
var audio_stream: AudioStream = load("res://assets/audio/voice/ziemek_greeting.wav")
var caption_duration := audio_stream.get_length()
```

#### Strategy 2: Metadata-Based

```gdscript
# Store caption timing in dialogue data
var dialogue_data := {
    "lines": [
        {
            "id": "ziemek_001",
            "text": "Witaj w naszej przygodzie!",
            "audio": "res://assets/audio/voice/ziemek_001.wav",
            "caption": "Welcome to our adventure!",
            "caption_duration": 2.5,
            "character": "ziemek"
        }
    ]
}
```

#### Strategy 3: Real-Time Sync with Audio Analysis

For precise synchronization (advanced):

```gdscript
# Analyze audio waveform to detect speech segments
func analyze_audio_for_silences(audio_stream: AudioStream, threshold_db: float = -30.0) -> Array[float]:
    # This would use audio analysis to find silent segments
    # Return array of timestamps where speech starts/stops
    return []
```

---

## Mixing & Level Balancing

### Volume Levels for Laptop Speakers

Based on testing requirements, all audio must be intelligible on laptop speakers.

#### Recommended Volume Levels

| Category | Volume (dB) | Priority | Notes |
|----------|-------------|----------|-------|
| Voice | -3.0 to 0.0 | Highest | Must be clear, slightly louder |
| Music | -12.0 to -6.0 | Low | Background, ducks during voice |
| SFX (Important) | -6.0 to -3.0 | Medium | Combat, interactions |
| SFX (Ambient) | -12.0 to -9.0 | Low | Background effects |
| Footsteps | -9.0 to -6.0 | Medium | Subtle but audible |
| Whoosh | -6.0 to -3.0 | Medium | Action feedback |
| Physical Impacts | -3.0 to 0.0 | High | Important feedback |

#### Dynamic Range Compression

To ensure intelligibility on laptop speakers:

```gdscript
# Configure compressor for Voice bus
func configure_voice_bus_for_laptop() -> void:
    var index := AudioServer.get_bus_index("Voice")
    
    # Clear existing effects
    while AudioServer.get_bus_effect_count(index) > 0:
        AudioServer.remove_bus_effect(index, 0)
    
    # Add compressor for consistent levels
    var compressor := AudioEffectCompressor.new()
    compressor.threshold_db = -24.0  # Compress quiet parts
    compressor.ratio = 8.0          # Strong compression
    compressor.attack_sec = 0.01    # Fast attack
    compressor.release_sec = 0.1    # Moderate release
    compressor.knee_db = 3.0        # Smooth transition
    compressor.makeup_gain_db = 4.0 # Boost to compensate
    
    AudioServer.add_bus_effect(index, compressor)
    
    # Add limiter for final protection
    var limiter := AudioEffectLimiter.new()
    limiter.threshold_db = -3.0
    limiter.soft_clip = true
    
    AudioServer.add_bus_effect(index, limiter)
```

### Mixing Presets for Different Scenes

```gdscript
# audio_mix_presets.gd

class_name AudioMixPresets

# Presets for different game states
var presets := {
    "default": {
        "Music": -6.0,
        "Voice": 0.0,
        "SFX": -3.0,
        "UI": -6.0,
        "Ambient": -12.0
    },
    "dialogue": {
        "Music": -12.0,  # Ducked
        "Voice": 0.0,
        "SFX": -6.0,   # Lower during dialogue
        "UI": -6.0,
        "Ambient": -15.0
    },
    "combat": {
        "Music": -9.0,
        "Voice": -3.0,  # Lower to hear combat SFX
        "SFX": 0.0,
        "UI": -6.0,
        "Ambient": -18.0
    },
    "cinematic": {
        "Music": -3.0,   # Louder for cinematics
        "Voice": 0.0,
        "SFX": -3.0,
        "UI": -12.0,    # Hide UI sounds
        "Ambient": -12.0
    }
}

func apply_preset(preset_name: String, fade_duration: float = 0.5) -> void:
    if not presets.has(preset_name):
        return
    
    var preset := presets[preset_name]
    
    for bus_name in preset:
        var target_db := preset[bus_name]
        AudioUtils.fade_bus_volume(bus_name, target_db, fade_duration)
```

---

## Code Samples & Implementation Patterns

### Complete Dialogue System Integration

```gdscript
# src/adapters/inbound/gameplay/dialogue_manager.gd

class_name DialogueManager
extends Node

# Dependencies
@onready var voice_queue: VoiceQueue = $VoiceQueue
@onready var audio_manager: AudioManager = get_node("/root/AudioManager")
@onready var subtitle_queue: SubtitleQueue = get_node("/root/World/SubtitleQueue")

# Dialogue state
var current_dialogue: Dictionary = null
var current_line_index: int = 0
var is_playing: bool = false

# Dialogue data
@export var dialogue_database: Resource

func _ready() -> void:
    # Initialize systems
    voice_queue.voice_started.connect(_on_voice_started)
    voice_queue.voice_finished.connect(_on_voice_finished)

# Start a dialogue
func start_dialogue(dialogue_id: String) -> void:
    if is_playing:
        return
    
    current_dialogue = dialogue_database.get_dialogue(dialogue_id)
    current_line_index = 0
    is_playing = true
    
    # Apply dialogue mix preset
    audio_manager.apply_preset("dialogue")
    
    _play_next_line()

func _play_next_line() -> void:
    if not current_dialogue or current_line_index >= current_dialogue["lines"].size():
        _end_dialogue()
        return
    
    var line := current_dialogue["lines"][current_line_index]
    current_line_index += 1
    
    # Load audio stream
    var audio_stream := load(line["audio"])
    
    # Enqueue voice with caption
    voice_queue.enqueue_voice(
        line["character"],
        line["id"],
        audio_stream,
        line.get("caption", ""),
        line.get("priority", 0)
    )

func _on_voice_started(character: String, line_id: String) -> void:
    # Optional: Trigger character animation
    _trigger_character_animation(character, "talk_start")

func _on_voice_finished(character: String, line_id: String) -> void:
    # Optional: Trigger character animation
    _trigger_character_animation(character, "talk_end")
    
    # Play next line
    _play_next_line()

func _trigger_character_animation(character: String, animation: String) -> void:
    var character_node := get_node("/root/World/Characters/%s" % character)
    if character_node:
        character_node.play_animation(animation)

func _end_dialogue() -> void:
    is_playing = false
    current_dialogue = null
    current_line_index = 0
    
    # Restore default mix
    audio_manager.apply_preset("default")

func skip_dialogue() -> void:
    voice_queue.interrupt_voice()
    voice_queue.clear_queue()
    _end_dialogue()

func is_dialogue_playing() -> bool:
    return is_playing
```

### Dialogue Data Structure

```json
{
  "dialogues": [
    {
      "id": "intro_welcome",
      "title": "Welcome Dialogue",
      "lines": [
        {
          "id": "ziemek_001",
          "character": "ziemek",
          "text": "Witaj w naszej przygodzie! Jestem Ziemek.",
          "audio": "res://assets/audio/voice/ziemek_001.wav",
          "caption": "Welcome to our adventure! I am Ziemek.",
          "caption_duration": 2.8,
          "priority": 0,
          "emotion": "happy",
          "animation": "greet"
        },
        {
          "id": "gniewko_001",
          "character": "gniewko",
          "text": "A ja jestem Gniewko! Gotowy na przygodę?",
          "audio": "res://assets/audio/voice/gniewko_001.wav",
          "caption": "And I am Gniewko! Ready for adventure?",
          "caption_duration": 2.5,
          "priority": 0,
          "emotion": "excited",
          "animation": "exclaim"
        }
      ]
    }
  ]
}
```

### Launcher Sequence with Voices

```gdscript
# src/adapters/inbound/scenes/launcher/launcher_overlay.gd

class_name LauncherOverlay
extends CanvasLayer

@onready var play_button: Button = $PlayButton
@onready var audio_manager: AudioManager = get_node("/root/AudioManager")

# Launcher sequence
var sequence: Array = []
var current_step: int = 0
var is_sequence_playing: bool = false

func _ready() -> void:
    # Define launcher sequence
    sequence = [
        {"type": "voice", "character": "ziemek", "audio": "res://assets/audio/voice/ziemek_launcher_01.wav", "caption": "Cześć! Gotowy na nową przygodę?", "delay": 1.0},
        {"type": "voice", "character": "gniewko", "audio": "res://assets/audio/voice/gniewko_launcher_01.wav", "caption": "Oczywiście! Będziemy cię prowadzić.", "delay": 0.5},
        {"type": "music", "audio": "res://assets/audio/music/launcher_theme.wav", "volume": -8.0, "delay": 1.0},
        {"type": "enable", "target": "PlayButton", "delay": 2.0}
    ]
    
    play_button.pressed.connect(_on_play_pressed)

func start_sequence() -> void:
    if is_sequence_playing:
        return
    
    is_sequence_playing = true
    current_step = 0
    _play_next_step()

func _play_next_step() -> void:
    if current_step >= sequence.size():
        is_sequence_playing = false
        return
    
    var step := sequence[current_step]
    current_step += 1
    
    if step.has("delay") and step["delay"] > 0:
        await get_tree().create_timer(step["delay"]).timeout
    
    match step["type"]:
        "voice":
            var audio_stream := load(step["audio"])
            audio_manager.play_voice(audio_stream, step.get("caption", ""), step.get("character", ""))
            
        "music":
            var audio_stream := load(step["audio"])
            audio_manager.play_music(audio_stream, step.get("fade_in", 1.0))
            
        "enable":
            var target := get_node(step["target"])
            if target:
                target.disabled = false
                target.visible = true
    
    # Continue to next step after voice finishes (approximate)
    if step["type"] == "voice":
        var audio_stream := load(step["audio"])
        await get_tree().create_timer(audio_stream.get_length()).timeout
    
    _play_next_step()

func _on_play_pressed() -> void:
    # Start the game
    get_tree().change_scene_to_file("res://adapters/inbound/gameplay/gameplay_runtime.tscn")
```

---

## Asset Sources & Voice Management

### Voice Generation Workflow

#### Step 1: Generate Voice Lines

```python
# scripts/audio/generate_ziemek_gniewko.py
import os
import json
import requests
from pathlib import Path

# Configuration
API_KEY = os.environ["ELEVENLABS_API_KEY"]
VOICE_MAP = {
    "ziemek": "S1...",  # Wojciech or Konwersacyjny Kamil
    "gniewko": "S1..."  # Adam or Kamil
}

# Dialogue data
DIALOGUE_FILE = Path("data/dialogue/ziemek_gniewko.json")
OUTPUT_DIR = Path("res://assets/audio/voice")

# Emotion presets for voice generation
EMOTIONS = {
    "neutral": {"stability": 0.7, "similarity_boost": 0.7, "style": 0.0},
    "happy": {"stability": 0.5, "similarity_boost": 0.5, "style": 0.3},
    "excited": {"stability": 0.4, "similarity_boost": 0.4, "style": 0.5},
    "sad": {"stability": 0.8, "similarity_boost": 0.8, "style": 0.1},
    "angry": {"stability": 0.6, "similarity_boost": 0.6, "style": 0.4},
}

def generate_tts(text, voice_id, emotion="neutral"):
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
    headers = {
        "xi-api-key": API_KEY,
        "Content-Type": "application/json"
    }
    data = {
        "text": text,
        "model_id": "eleven_multilingual_v2",
        "voice_settings": EMOTIONS.get(emotion, EMOTIONS["neutral"])
    }
    
    response = requests.post(url, headers=headers, json=data)
    return response.content if response.status_code == 200 else None

def main():
    with open(DIALOGUE_FILE, 'r', encoding='utf-8') as f:
        dialogue_data = json.load(f)
    
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    for dialogue in dialogue_data["dialogues"]:
        for line in dialogue["lines"]:
            character = line["character"]
            voice_id = VOICE_MAP[character]
            text = line["text"]
            emotion = line.get("emotion", "neutral")
            
            filename = f"{character}_{line['id']}.wav"
            filepath = OUTPUT_DIR / filename
            
            if not filepath.exists():
                print(f"Generating: {filename}")
                audio_data = generate_tts(text, voice_id, emotion)
                if audio_data:
                    with open(filepath, 'wb') as f:
                        f.write(audio_data)
                    print(f"  Saved: {filepath}")
                else:
                    print(f"  Failed: {filename}")

if __name__ == "__main__":
    main()
```

#### Step 2: Verify and Optimize Audio

```python
# scripts/audio/verify_voice_assets.py
import os
from pathlib import Path
from pydub import AudioSegment

VOICE_DIR = Path("res://assets/audio/voice")

# Target specifications
TARGET_FORMAT = "wav"
TARGET_SAMPLE_RATE = 44100
TARGET_BITS = 16
TARGET_CHANNELS = 1  # Mono for voice

def check_audio_file(filepath):
    try:
        audio = AudioSegment.from_file(filepath)
        
        issues = []
        
        if audio.sample_width != 2:  # 16-bit = 2 bytes
            issues.append("Not 16-bit")
        
        if audio.frame_rate != TARGET_SAMPLE_RATE:
            issues.append(f"Sample rate: {audio.frame_rate} (target: {TARGET_SAMPLE_RATE})")
        
        if audio.channels != TARGET_CHANNELS:
            issues.append(f"Channels: {audio.channels} (target: {TARGET_CHANNELS})")
        
        # Check for clipping
        if audio.max_dBFS > -1.0:
            issues.append(f"Clipping detected: {audio.max_dBFS:.1f} dBFS")
        
        return issues
    except Exception as e:
        return [f"Error: {str(e)}"]

def convert_audio_file(filepath):
    audio = AudioSegment.from_file(filepath)
    
    # Convert to target format
    audio = audio.set_frame_rate(TARGET_SAMPLE_RATE)
    audio = audio.set_channels(TARGET_CHANNELS)
    audio = audio.set_sample_width(2)
    
    # Normalize to -3 dB
    audio = audio.normalize(headroom=3)
    
    # Save as WAV
    target_path = filepath.with_suffix(f".{TARGET_FORMAT}")
    audio.export(target_path, format=TARGET_FORMAT)
    
    return target_path

def main():
    issues_found = 0
    
    for filepath in VOICE_DIR.glob(f"*.{TARGET_FORMAT}"):
        issues = check_audio_file(filepath)
        if issues:
            print(f"{filepath.name}: {', '.join(issues)}")
            issues_found += 1
            # Optionally convert
            # convert_audio_file(filepath)
    
    if issues_found == 0:
        print("All voice assets pass verification!")
    else:
        print(f"\n{issues_found} files have issues.")

if __name__ == "__main__":
    main()
```

#### Step 3: Create Voice Pack Manifest

```json
{
  "voice_pack": {
    "name": "Ziemek & Gniewko - Polish Voices",
    "version": "1.0",
    "characters": {
      "ziemek": {
        "voice_id": "S1...",
        "voice_name": "Wojciech",
        "description": "Warm, friendly guide voice",
        "lines": [
          {"id": "ziemek_001", "file": "res://assets/audio/voice/ziemek_001.wav", "duration": 2.8, "text": "Witaj w naszej przygodzie! Jestem Ziemek."},
          {"id": "ziemek_002", "file": "res://assets/audio/voice/ziemek_002.wav", "duration": 3.2, "text": "Tutaj możesz zebrać drewno używając siekiery."}
        ]
      },
      "gniewko": {
        "voice_id": "S1...",
        "voice_name": "Adam",
        "description": "Energetic, adventurous voice",
        "lines": [
          {"id": "gniewko_001", "file": "res://assets/audio/voice/gniewko_001.wav", "duration": 2.5, "text": "A ja jestem Gniewko! Gotowy na przygodę?"},
          {"id": "gniewko_002", "file": "res://assets/audio/voice/gniewko_002.wav", "duration": 2.8, "text": "Pamiętaj, żeby uważać na niebezpieczeństwa!"}
        ]
      }
    },
    "metadata": {
      "generated_with": "ElevenLabs TTS",
      "model": "eleven_multilingual_v2",
      "sample_rate": 44100,
      "format": "WAV",
      "channels": 1
    }
  }
}
```

---

## Best Practices

### Voice Recording & Generation

#### 1. **Text Preparation**

- **Polish Language**: Ensure proper Polish punctuation and formatting
- **SSML Support**: ElevenLabs supports SSML for advanced formatting
- **Breathing**: Add natural pauses with commas, periods, and explicit breaks
- **Emphasis**: Use italics or SSML `<emphasis>` tags for important words

```python
# SSML example for ElevenLabs
ssml_text = """
<speak>
    <p>
        <s>Witaj w naszej <emphasis level="strong">przygodzie</emphasis>!</s>
        <break time="500ms"/>
        <s>Jestem <prosody rate="slow" pitch="high">Ziemek</prosody>.</s>
    </p>
</speak>
"""
```

#### 2. **Voice Consistency**

- Use the same voice ID for the same character throughout
- Apply consistent voice settings (stability, similarity_boost)
- Store voice settings with dialogue data for reproducibility

#### 3. **Audio Quality**

- Target **44.1 kHz, 16-bit, Mono** for voice files
- Normalize to **-3 dB to -6 dB** peak for consistency
- Remove silence from start/end of files
- Ensure no clipping (> -1 dBFS)

### Implementation Best Practices

#### 1. **Voice Queue Design**

- **Single Player**: Simplest, ensures no overlap
- **Priority Queue**: Important lines can interrupt
- **Character Isolation**: Prevent same-character overlap
- **Fade Transitions**: Smooth volume changes between lines

#### 2. **Caption Synchronization**

- Use audio file duration for automatic timing
- Provide manual override for precise sync
- Include speaker identification in captions
- Support multiple caption display modes

#### 3. **Performance**

- Pool AudioStreamPlayer nodes (8-16 players)
- Preload voice audio for critical dialogue
- Stream large audio files instead of loading entirely
- Cache recently used voice lines

### Accessibility Considerations

- **Caption Size**: Small (18pt), Medium (24pt), Large (32pt)
- **Caption Color**: White text with black outline on semi-transparent background
- **Caption Position**: Bottom-center, with speaker label
- **Caption Duration**: Match audio + 0.5s buffer
- **Reduce Motion**: Respect setting, but keep captions visible

---

## Testing & Validation Checklist

### Voice System Testing

- [ ] **Voice Distinction**
  - [ ] Ziemek voice is clearly distinct from Gniewko
  - [ ] Both voices are masculine and youthful
  - [ ] Voices have emotional range (happy, serious, excited)
  - [ ] Polish pronunciation is accurate
  
- [ ] **Queue System**
  - [ ] Voice lines play sequentially without overlap
  - [ ] No gaps between consecutive lines
  - [ ] Priority lines can interrupt lower-priority lines
  - [ ] Queue respects character isolation (same character doesn't overlap)
  
- [ ] **Caption System**
  - [ ] Captions appear with voice lines
  - [ ] Captions are synchronized (within 200ms)
  - [ ] Speaker identification is shown
  - [ ] Captions clear after voice finishes
  
- [ ] **Audio Quality**
  - [ ] No clipping or distortion in voice files
  - [ ] Consistent volume levels across all lines
  - [ ] No background noise or artifacts
  - [ ] Proper Polish accent and intonation

### Audio Mix Testing

- [ ] **Volume Balance (Laptop Speakers)**
  - [ ] Voice is clear and intelligible
  - [ ] Music is audible but doesn't overpower voice
  - [ ] SFX are distinct and appropriately loud
  - [ ] All audio elements are audible simultaneously
  
- [ ] **Spatial Audio**
  - [ ] Voice originates from character position
  - [ ] Volume decreases with distance
  - [ ] Panning works (left/right positioning)
  - [ ] Doppler effect is subtle and realistic
  
- [ ] **Scene Transitions**
  - [ ] Voice plays correctly during launcher sequence
  - [ ] Voice continues during scene changes
  - [ ] Audio doesn't glitch or cut out during transitions

### Integration Testing

- [ ] **Dialogue Flow**
  - [ ] Full launcher sequence plays correctly
  - [ ] Guide dialogue triggers properly
  - [ ] NPC interactions have voice and captions
  - [ ] Combat taunts are audible
  
- [ ] **Error Handling**
  - [ ] Missing voice files have fallback behavior
  - [ ] Network errors during TTS generation are handled
  - [ ] Audio load failures don't crash the game
  
- [ ] **Accessibility**
  - [ ] Captions work when enabled
  - [ ] Captions respect size settings
  - [ ] Captions are readable on all backgrounds

### Performance Testing

- [ ] **Memory Usage**
  - [ ] Voice queue doesn't leak memory
  - [ ] Audio files are properly released
  - [ ] Caching doesn't grow unbounded
  
- [ ] **CPU Usage**
  - [ ] Audio processing < 5% CPU
  - [ ] No audio-related frame drops
  
- [ ] **Load Times**
  - [ ] Voice lines load quickly (< 100ms)
  - [ ] Preloading reduces first-play delay

---

## Learning Resources

### Cutscene Orchestration Pattern (reviewed 2026-07-18)

The supplied Godot Forum discussion, ["Looking for a smart way of animating 3D cutscenes with characters in AnimationPlayer"](https://forum.godotengine.org/t/looking-for-a-smart-way-of-animating-3d-cutscenes-with-characters-in-animationplayer/104546/11), supports a modular arrangement that fits this project:

- Each cinematic character owns an `AnimationPlayer` containing its imported clips and an `AnimationTree` which handles blends, state transitions, and short parallel reactions.
- A separate cutscene-level `AnimationPlayer` owns the 5–10 second timeline: camera cuts/moves, lighting, timing markers, character action parameters, caption triggers, and the handoff to the launcher.
- The cutscene controller temporarily disables player input, snapshots the gameplay camera/player state, and restores it on skip or completion. This prevents the launch montage from becoming a second gameplay controller.

**Decision for VS-015/VS-032:** retain the current lightweight launcher sequence until the CC0 animation library has been checked against the active character skeletons. Then replace direct transform-only character tweening with this three-layer pattern—not a single monolithic animation or an externally rendered movie. The opening must include at least two intentional camera compositions (establishing/approach and impact/reaction) and preserve a clean skip-to-launcher path.

**Validation additions:** test that a skip or completion restores input/camera state; verify only one cutscene timeline runs at once; inspect two captured camera frames so a hero or monster cannot be clipped out of the viewport.

### Official Documentation

| Resource | URL |
|----------|-----|
| ElevenLabs API Reference | [https://elevenlabs.io/docs/api-reference](https://elevenlabs.io/docs/api-reference) |
| ElevenLabs TTS Documentation | [https://elevenlabs.io/docs/overview/capabilities/text-to-speech](https://elevenlabs.io/docs/overview/capabilities/text-to-speech) |
| Godot AudioStreamPlayer | [https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html) |
| Godot AudioStreamPlayer3D | [https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html) |

### Godot Plugins & Addons

| Plugin | URL | Purpose |
|--------|-----|---------|
| Wiechciu/eleven-labs | [https://github.com/Wiechciu/eleven-labs](https://github.com/Wiechciu/eleven-labs) | Official ElevenLabs plugin |
| SpatialAudio3D | [https://github.com/claudehohl/SpatialAudio3D](https://github.com/claudehohl/SpatialAudio3D) | Advanced spatial audio |
| Dialogue Manager | [https://dialogue.nathanhoad.net/](https://dialogue.nathanhoad.net/) | Complete dialogue system |

### Tutorials & Guides

| Resource | URL |
|----------|-----|
| Godot Dialogue System Tutorial | [https://codingquests.io/blog/godot-4-dialogue-system-tutorial](https://codingquests.io/blog/godot-4-dialogue-system-tutorial) |
| Dialogue & Quest Systems | [https://www.strayspark.studio/blog/godot-4-dialogue-quest-systems-signals-resources](https://www.strayspark.studio/blog/godot-4-dialogue-quest-systems-signals-resources) |
| JRPG Dialogues in Godot 4 | [https://medium.com/codex/setting-up-basic-jrpg-like-dialogues-godot-4-c-1574eb28e548](https://medium.com/codex/setting-up-basic-jrpg-like-dialogues-godot-4-c-1574eb28e548) |
| Audio Manager Recipe | [https://kidscancode.org/godot_recipes/4.x/audio/audio_manager/index.html](https://kidscancode.org/godot_recipes/4.x/audio/audio_manager/index.html) |
| Godot Audio Guide | [https://uhiyama-lab.com/en/notes/godot/godot-audio-management-basics-audiostreamplayer-audiobus/](https://uhiyama-lab.com/en/notes/godot/godot-audio-management-basics-audiostreamplayer-audiobus/) |

### Community Resources

| Resource | URL |
|----------|-----|
| Godot Forum - Audio | [https://forum.godotengine.org/c/audio](https://forum.godotengine.org/c/audio) |
| Godot Discord | [https://discord.gg/4JBkykG](https://discord.gg/4JBkykG) |
| Reddit - r/godot | [https://www.reddit.com/r/godot/](https://www.reddit.com/r/godot/) |
| ElevenLabs Community | [https://community.elevenlabs.io/](https://community.elevenlabs.io/) |

### Example Projects

| Project | URL |
|---------|-----|
| AI NPC Example | [https://github.com/teddybear082/godot-ai-npc-example](https://github.com/teddybear082/godot-ai-npc-example) |
| ChatGPT Stream for Godot 4 | [https://github.com/oceanbuilders/ChatGPT-stream-for-Godot-4](https://github.com/oceanbuilders/ChatGPT-stream-for-Godot-4) |

---

## Summary & Recommendations

### Key Findings

1. **ElevenLabs Integration**: Use official plugin ([Wiechciu/eleven-labs](https://github.com/Wiechciu/eleven-labs)) or custom HTTPRequest implementation
2. **Polish Voices**: Wojciech and Konwersacyjny Kamil are ideal for Ziemek (guide), Adam or Kamil for Gniewko (companion)
3. **Queue System**: Single-player queue ensures no overlap; priority system allows interruption
4. **Caption Sync**: Use audio duration for automatic timing; support manual overrides
5. **Spatial Audio**: AudioStreamPlayer3D with inverse-square attenuation works well
6. **Mixing**: Voice at 0 dB to -3 dB, music at -6 dB to -12 dB, SFX at -3 dB to -6 dB

### Implementation Priority

1. **High Priority**:
   - ElevenLabs API integration and voice generation
   - Single-voice queue system preventing overlap
   - Basic caption synchronization
   - Voice spatialization
   
2. **Medium Priority**:
   - Priority queue for important lines
   - Per-character voice isolation
   - Advanced caption styling and positioning
   - Audio mixing presets
   
3. **Low Priority**:
   - SSML support for advanced voice formatting
   - Real-time TTS generation (vs. pre-generated)
   - Advanced spatial audio (SpatialAudio3D plugin)
   - Voice caching and preloading

### Estimated Effort

| Task | Complexity | Estimated Hours | Dependencies |
|------|------------|-----------------|--------------|
| ElevenLabs Integration | Medium | 4-6 | API Key, Plugin Setup |
| Voice Generation Script | Medium | 4-8 | ElevenLabs Access |
| Queue System | Medium | 6-8 | Audio Manager |
| Caption Sync | Medium | 4-6 | Subtitle System |
| Spatial Audio | Medium | 4-6 | Character System |
| Mixing & Testing | High | 8-12 | All audio systems |
| **Total** | | **30-56 hours** | |

### Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| ElevenLabs API changes | Low | Medium | Use versioned API, cache responses |
| Voice quality issues | Medium | High | Test voices early, have backups |
| Polish pronunciation errors | Medium | High | Use native speakers for review |
| Audio sync issues | Medium | Medium | Test on multiple devices |
| Performance bottlenecks | Low | Medium | Profile early, optimize loading |

---

## Next Steps

1. **Setup ElevenLabs Integration**: Install plugin or implement HTTPRequest client
2. **Generate Voice Lines**: Use Python script to generate all dialogue lines
3. **Verify Audio Quality**: Check all voice files for clipping, volume, and clarity
4. **Implement Queue System**: Create VoiceQueue node with single-player design
5. **Integrate Captions**: Connect voice queue to subtitle display system
6. **Configure Spatial Audio**: Set up AudioStreamPlayer3D for character voices
7. **Test on Laptop**: Validate all audio levels on target hardware
8. **Create Launcher Sequence**: Implement Ziemek/Gniewko intro dialogue

---

*Document Version: 1.1*
*Generated: 2026-07-18*  
*Status: Ready for Implementation Review*
