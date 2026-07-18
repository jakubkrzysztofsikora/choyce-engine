# PLAN-014: Audio Bus Architecture & Mixing System - Deep Research Compendium

**Status**: in_progress  
**Specialty**: godot-audio-engineering  
**Gate**: Gate 3 (PLAN.md Line 235) & Foundation (PLAN.md Section 317)  
**Priority**: HIGH  
**Last Updated**: 2026-07-18  
**Child-Safety Consideration**: Audio must be balanced, non-startling, with dialogue always clear and audible over music/SFX

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Audio Architecture Fundamentals](#audio-architecture-fundamentals)
3. [Bus Layout Design for Choyce Engine](#bus-layout-design-for-choyce-engine)
4. [Bus Configuration & Routing](#bus-configuration--routing)
5. [Audio Effects Chain](#audio-effects-chain)
6. [Volume Management System](#volume-management-system)
7. [Audio Node Assignment](#audio-node-assignment)
8. [Dynamic Audio Control](#dynamic-audio-control)
9. [Accessibility & Child-Safety](#accessibility--child-safety)
10. [Integration with Other Systems](#integration-with-other-systems)
11. [Code Samples & Implementation Patterns](#code-samples--implementation-patterns)
12. [Testing & Validation Checklist](#testing--validation-checklist)
13. [Learning Resources](#learning-resources)

---

## Task Overview

### Objective

Implement a **comprehensive audio bus architecture** in Godot 4.x for Choyce Engine that:
- Routes all audio (music, SFX, voice, ambience) through explicit buses
- Validates levels and ensures blocking cues are audible (PLAN.md line 235)
- Integrates with continuous exploration music (PLAN-012)
- Supports child-safe audio balancing (dialogue > music > SFX)
- Provides runtime control over audio levels
- Enables effects processing (EQ, compression, reverb) per bus

### Source Reference

From PLAN.md Gate 3 (line 235):
> Route music/SFX/voice through explicit buses and **validate levels and blocking cues**.

From PLAN.md Foundation (line 317-320):
> **Foundation:** collision dimensions are world metres rather than scaled proxy guesses; preserve native materials; use a camera ray and 3D preview for TPP building; real ground/dirt collision; a water volume with wading/swim physics; continuous exploration music; no legacy Ninja overlay.

### Key Requirements

- ✅ **Explicit bus routing**: All audio goes through defined buses
- ✅ **Level validation**: Music stays below dialogue, important cues are audible
- ✅ **Blocking cues**: Critical SFX (combat hits, warnings) cut through music
- ✅ **Child-safe**: No startling loud noises, balanced volumes
- ✅ **Runtime control**: Volume sliders for each bus
- ✅ **Effects support**: EQ, compression, reverb per bus
- ✅ **Integration**: Works with PLAN-012 (music), PLAN-005 (combat), VS-015 (voice)

### Acceptance Criteria

1. All audio nodes assigned to appropriate buses
2. Music bus volume < dialogue bus volume
3. Critical SFX can be heard over music
4. Bus effects configured appropriately
5. Runtime volume control works
6. No audio clipping or distortion
7. Audio levels consistent across scenes
8. Settings persist between sessions

---

## Audio Architecture Fundamentals

### Godot Audio Server Hierarchy

```
AudioServer (Singleton)
├── Audio Buses (Configurable)
│   ├── Master (Index: 0, Default Output)
│   ├── Music (Index: 1)
│   ├── SFX (Index: 2)
│   ├── Dialogue (Index: 3)
│   ├── Ambience (Index: 4)
│   └── UI (Index: 5)
└── Audio Effects (Per Bus)
    ├── EQ (Frequency shaping)
    ├── Compressor (Dynamic range)
    ├── Reverb (Spatial ambience)
    └── Limiter (Peak protection)
```

### Audio Flow

```
AudioStreamPlayer (Music)
    → Bus: Music
        → Effect: EQ (boost bass slightly)
        → Effect: Compressor (gentle)
        → Effect: Limiter
    → Bus: Master
        → Effect: Limiter (final protection)
        → Output: System Audio
```

### Key Concepts

| Concept | Description | Choyce Implementation |
|---------|-------------|----------------------|
| **Bus** | Audio routing channel | Music, SFX, Dialogue, Ambience, UI |
| **Send** | Route audio to another bus | Music → Master, SFX → Master |
| **Effect** | Audio processing | EQ, Compressor, Reverb, Limiter |
| **Volume** | Loudness in decibels | Master: 0dB, Music: -6dB, Dialogue: 0dB |
| **Mute** | Silence a bus | Independent per bus |
| **Solo** | Isolate a bus | For debugging |
| **Bypass** | Skip effects | Per effect |

---

## Bus Layout Design for Choyce Engine

### Recommended Bus Structure

| Bus Name | Index | Purpose | Send To | Effects | Volume (dB) |
|----------|-------|---------|--------|---------|------------|
| Master | 0 | Final output | System | Limiter | 0.0 |
| Music | 1 | Background music | Master | EQ, Compressor | -6.0 |
| SFX | 2 | Sound effects | Master | EQ, Compressor, Limiter | 0.0 |
| Dialogue | 3 | Voice lines | Master | Compressor, Limiter | 0.0 |
| Ambience | 4 | Environmental sounds | Master | EQ, Reverb | -3.0 |
| UI | 5 | Menu/interface sounds | Master | Limiter | 0.0 |

### Bus Hierarchy Visualization

```
                        ┌─────────────────┐
                        │      MASTER      │ ← Limiter
                        │    (Index 0)     │
                        └────────┬────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
┌───────▼───────┐   ┌───────▼───────┐   ┌───────▼───────┐
│     MUSIC     │   │      SFX      │   │   DIALOGUE    │
│   (Index 1)   │   │    (Index 2)   │   │   (Index 3)   │
│ EQ + Compress │   │ EQ + Comp + Lim│   │ Comp + Lim    │
└───────┬───────┘   └───────┬───────┘   └───────┬───────┘
        │                        │                        │
┌───────▼───────┐   ┌───────▼───────┐   ┌───────▼───────┐
│ AudioStreamPlayer │   │ AudioStreamPlayer │   │ AudioStreamPlayer │
│   (BGM tracks)    │   │   (SFX instances)│   │   (Voice lines) │
└────────────────┘   └────────────────┘   └────────────────┘

┌───────▼───────┐   ┌───────▼───────┐
│   AMBIENCE    │   │       UI       │
│   (Index 4)   │   │    (Index 5)   │
│ EQ + Reverb   │   │    Limiter     │
└───────────────┘   └───────────────┘
```

### Rationale for This Structure

1. **Music at -6dB**: Ensures music doesn't overpower dialogue (Gate 3 requirement)
2. **Dialogue at 0dB**: Voice lines are clear and prominent
3. **SFX at 0dB**: Can be heard clearly, but individual SFX have volume adjustments
4. **Ambience at -3dB**: Subtle background, doesn't compete with gameplay audio
5. **UI at 0dB**: Menu sounds are clear but not distracting

---

## Bus Configuration & Routing

### Project Settings Configuration

**Step 1: Open Audio Settings**
- Go to: Project → Project Settings → Audio → Buses

**Step 2: Configure Buses**

```ini
# project.godot - Audio Buses section
[audio]

# Bus count (default + custom)
bus_count = 6

# Bus names
bus/0/name = "Master"
bus/1/name = "Music"
bus/2/name = "SFX"
bus/3/name = "Dialogue"
bus/4/name = "Ambience"
bus/5/name = "UI"

# Bus sends (route to parent bus)
bus/1/send = "Master"
bus/2/send = "Master"
bus/3/send = "Master"
bus/4/send = "Master"
bus/5/send = "Master"

# Bus volumes (dB)
bus/0/volume_db = 0.0
bus/1/volume_db = -6.0
bus/2/volume_db = 0.0
bus/3/volume_db = 0.0
bus/4/volume_db = -3.0
bus/5/volume_db = 0.0

# Bus mute states
bus/0/mute = false
bus/1/mute = false
bus/2/mute = false
bus/3/mute = false
bus/4/mute = false
bus/5/mute = false
```

### Programmatic Bus Configuration

```gdscript
# audio_bus_manager.gd

func configure_buses() -> void:
    # Set bus count (must be done before adding buses)
    AudioServer.set_bus_count(6)
    
    # Configure each bus
    _configure_master_bus()
    _configure_music_bus()
    _configure_sfx_bus()
    _configure_dialogue_bus()
    _configure_ambience_bus()
    _configure_ui_bus()

func _configure_master_bus() -> void:
    var bus_idx := AudioServer.get_bus_index("Master")
    AudioServer.set_bus_volume_db(bus_idx, 0.0)
    AudioServer.set_bus_mute(bus_idx, false)
    _add_limiter_to_bus(bus_idx)

func _configure_music_bus() -> void:
    var bus_idx := AudioServer.get_bus_index("Music")
    AudioServer.set_bus_volume_db(bus_idx, -6.0)
    AudioServer.set_bus_mute(bus_idx, false)
    AudioServer.set_bus_send(bus_idx, AudioServer.get_bus_index("Master"))
    
    # Add effects in order: EQ → Compressor → Limiter
    _add_eq_to_bus(bus_idx, "music")
    _add_compressor_to_bus(bus_idx, "music")
    _add_limiter_to_bus(bus_idx, "music")

func _configure_sfx_bus() -> void:
    var bus_idx := AudioServer.get_bus_index("SFX")
    AudioServer.set_bus_volume_db(bus_idx, 0.0)
    AudioServer.set_bus_mute(bus_idx, false)
    AudioServer.set_bus_send(bus_idx, AudioServer.get_bus_index("Master"))
    
    # Add effects
    _add_eq_to_bus(bus_idx, "sfx")
    _add_compressor_to_bus(bus_idx, "sfx")
    _add_limiter_to_bus(bus_idx, "sfx")

func _configure_dialogue_bus() -> void:
    var bus_idx := AudioServer.get_bus_index("Dialogue")
    AudioServer.set_bus_volume_db(bus_idx, 0.0)
    AudioServer.set_bus_mute(bus_idx, false)
    AudioServer.set_bus_send(bus_idx, AudioServer.get_bus_index("Master"))
    
    # Dialogue needs clear compression to ensure intelligibility
    _add_compressor_to_bus(bus_idx, "dialogue")
    _add_limiter_to_bus(bus_idx, "dialogue")

func _configure_ambience_bus() -> void:
    var bus_idx := AudioServer.get_bus_index("Ambience")
    AudioServer.set_bus_volume_db(bus_idx, -3.0)
    AudioServer.set_bus_mute(bus_idx, false)
    AudioServer.set_bus_send(bus_idx, AudioServer.get_bus_index("Master"))
    
    # Ambience benefits from reverb for depth
    _add_eq_to_bus(bus_idx, "ambience")
    _add_reverb_to_bus(bus_idx, "ambience")

func _configure_ui_bus() -> void:
    var bus_idx := AudioServer.get_bus_index("UI")
    AudioServer.set_bus_volume_db(bus_idx, 0.0)
    AudioServer.set_bus_mute(bus_idx, false)
    AudioServer.set_bus_send(bus_idx, AudioServer.get_bus_index("Master"))
    
    # UI sounds need peak protection
    _add_limiter_to_bus(bus_idx, "ui")
```

---

## Audio Effects Chain

### Effect Types & Purpose

| Effect | Class | Purpose | Typical Settings |
|--------|-------|---------|------------------|
| EQ | `AudioEffectEQ`, `AudioEffectEQ6`, `AudioEffectEQ10`, `AudioEffectEQ21` | Frequency shaping | Band gains for tone control |
| Compressor | `AudioEffectCompressor` | Dynamic range control | Threshold, ratio, attack, release |
| Reverb | `AudioEffectReverb` | Spatial ambience | Room size, damp, wet/dry mix |
| Limiter | `AudioEffectLimiter` | Peak protection | Threshold, release |
| Chorus | `AudioEffectChorus` | Thickening | Rate, depth, feedback |
| Delay | `AudioEffectDelay` | Echo effects | Delay time, feedback |
| Filter | `AudioEffectLowPassFilter`, `AudioEffectHighPassFilter` | Frequency filtering | Cutoff frequency |

### Recommended Effect Chains

**Music Bus:**
```
Input → EQ (warm up) → Compressor (gentle) → Limiter → Master
```

**SFX Bus:**
```
Input → EQ (enhance impacts) → Compressor (moderate) → Limiter → Master
```

**Dialogue Bus:**
```
Input → Compressor (aggressive) → Limiter → Master
```

**Ambience Bus:**
```
Input → EQ (sculpt atmosphere) → Reverb (space) → Master
```

**UI Bus:**
```
Input → Limiter → Master
```

### Effect Configuration Examples

**EQ for Music (Warm, Full):**
```gdscript
func _add_eq_to_bus(bus_idx: int, preset: String) -> void:
    var eq := AudioEffectEQ10.new()
    
    match preset:
        "music":
            # Boost lows slightly, gentle high cut
            eq.set_band_gain_db(0, 3.0)   # 31Hz +3dB
            eq.set_band_gain_db(1, 2.0)   # 62Hz +2dB
            eq.set_band_gain_db(2, 1.0)   # 125Hz +1dB
            eq.set_band_gain_db(3, 0.0)   # 250Hz neutral
            eq.set_band_gain_db(4, 0.0)   # 500Hz neutral
            eq.set_band_gain_db(5, -1.0)  # 1kHz -1dB
            eq.set_band_gain_db(6, -1.0)  # 2kHz -1dB
            eq.set_band_gain_db(7, -2.0)  # 4kHz -2dB
            eq.set_band_gain_db(8, -3.0)  # 8kHz -3dB
            eq.set_band_gain_db(9, -4.0)  # 16kHz -4dB
        "sfx":
            # Enhance impact frequencies
            eq.set_band_gain_db(2, 2.0)   # 125Hz boost for thuds
            eq.set_band_gain_db(4, 2.0)   # 500Hz boost for clarity
            eq.set_band_gain_db(6, 1.0)   # 2kHz boost for presence
        "ambience":
            # Subtle low boost for depth
            eq.set_band_gain_db(0, 2.0)
            eq.set_band_gain_db(1, 1.5)
    
    AudioServer.add_bus_effect(bus_idx, eq)
```

**Compressor for Dialogue (Ensure Clarity):**
```gdscript
func _add_compressor_to_bus(bus_idx: int, preset: String) -> void:
    var compressor := AudioEffectCompressor.new()
    
    match preset:
        "music":
            # Gentle compression for music
            compressor.threshold_db = -20.0
            compressor.ratio = 2.0
            compressor.attack_us = 10000   # 10ms
            compressor.release_ms = 100   # 100ms
            compressor.makeup_gain_db = 0.0
        "sfx":
            # Moderate compression for SFX
            compressor.threshold_db = -15.0
            compressor.ratio = 3.0
            compressor.attack_us = 5000    # 5ms
            compressor.release_ms = 50    # 50ms
            compressor.makeup_gain_db = 1.0
        "dialogue":
            # Aggressive compression for dialogue clarity
            compressor.threshold_db = -24.0
            compressor.ratio = 4.0
            compressor.attack_us = 1000    # 1ms
            compressor.release_ms = 20    # 20ms
            compressor.makeup_gain_db = 3.0
    
    AudioServer.add_bus_effect(bus_idx, compressor)
```

**Reverb for Ambience:**
```gdscript
func _add_reverb_to_bus(bus_idx: int, preset: String) -> void:
    var reverb := AudioEffectReverb.new()
    
    match preset:
        "ambience":
            # Small room reverb for outdoor ambience
            reverb.room_size = 0.3
            reverb.damping = 0.5
            reverb.wet = 0.3
            reverb.dry = 0.7
            reverb.predelay_ms = 20.0
            reverb.decay_time = 1.5
        "cave":
            # Large cavern reverb
            reverb.room_size = 0.8
            reverb.damping = 0.3
            reverb.wet = 0.5
            reverb.dry = 0.5
            reverb.predelay_ms = 40.0
            reverb.decay_time = 3.0
    
    AudioServer.add_bus_effect(bus_idx, reverb)
```

**Limiter for Peak Protection:**
```gdscript
func _add_limiter_to_bus(bus_idx: int, preset: String = "") -> void:
    var limiter := AudioEffectLimiter.new()
    
    # Default settings work well for most cases
    limiter.threshold_db = -3.0
    limiter.release_ms = 10.0
    limiter.gain_boost_db = 0.0
    
    # Master bus limiter is more conservative
    if bus_idx == AudioServer.get_bus_index("Master"):
        limiter.threshold_db = -1.0  # Allow slightly more headroom
        limiter.release_ms = 5.0   # Faster release for transients
    
    AudioServer.add_bus_effect(bus_idx, limiter)
```

---

## Volume Management System

### Volume Settings System

**Architecture:**
```
SettingsManager (Singleton)
├── AudioSettings
│   ├── master_volume: float (-80.0 to 6.0)
│   ├── music_volume: float
│   ├── sfx_volume: float
│   ├── dialogue_volume: float
│   ├── ambience_volume: float
│   └── ui_volume: float
└── Methods
    ├── save_settings()
    ├── load_settings()
    └── apply_settings()
```

**Implementation:**

```gdscript
# audio_settings.gd
extends RefCounted

class_name AudioSettings

@export var master_volume: float = 0.0:
    set(value):
        master_volume = clamp(value, -80.0, 6.0)
        AudioServer.set_bus_volume_db(
            AudioServer.get_bus_index("Master"),
            master_volume
        )

@export var music_volume: float = -6.0:
    set(value):
        music_volume = clamp(value, -80.0, 6.0)
        AudioServer.set_bus_volume_db(
            AudioServer.get_bus_index("Music"),
            music_volume
        )

@export var sfx_volume: float = 0.0:
    set(value):
        sfx_volume = clamp(value, -80.0, 6.0)
        AudioServer.set_bus_volume_db(
            AudioServer.get_bus_index("SFX"),
            sfx_volume
        )

@export var dialogue_volume: float = 0.0:
    set(value):
        dialogue_volume = clamp(value, -80.0, 6.0)
        AudioServer.set_bus_volume_db(
            AudioServer.get_bus_index("Dialogue"),
            dialogue_volume
        )

@export var ambience_volume: float = -3.0:
    set(value):
        ambience_volume = clamp(value, -80.0, 6.0)
        AudioServer.set_bus_volume_db(
            AudioServer.get_bus_index("Ambience"),
            ambience_volume
        )

@export var ui_volume: float = 0.0:
    set(value):
        ui_volume = clamp(value, -80.0, 6.0)
        AudioServer.set_bus_volume_db(
            AudioServer.get_bus_index("UI"),
            ui_volume
        )

func to_dict() -> Dictionary:
    return {
        "master_volume": master_volume,
        "music_volume": music_volume,
        "sfx_volume": sfx_volume,
        "dialogue_volume": dialogue_volume,
        "ambience_volume": ambience_volume,
        "ui_volume": ui_volume
    }

func from_dict(data: Dictionary) -> void:
    master_volume = data.get("master_volume", 0.0)
    music_volume = data.get("music_volume", -6.0)
    sfx_volume = data.get("sfx_volume", 0.0)
    dialogue_volume = data.get("dialogue_volume", 0.0)
    ambience_volume = data.get("ambience_volume", -3.0)
    ui_volume = data.get("ui_volume", 0.0)
```

### Settings Manager

```gdscript
# settings_manager.gd
extends Node

const SETTINGS_FILE := "user://settings/audio_settings.json"

var audio_settings: AudioSettings

func _ready() -> void:
    audio_settings = AudioSettings.new()
    load_settings()

func save_settings() -> void:
    var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(audio_settings.to_dict()))
        file.close()

func load_settings() -> void:
    if FileAccess.file_exists(SETTINGS_FILE):
        var file := FileAccess.open(SETTINGS_FILE, FileAccess.READ)
        if file:
            var data := JSON.parse_string(file.get_as_text())
            audio_settings.from_dict(data)
            file.close()
    else:
        # Apply defaults
        apply_settings()

func apply_settings() -> void:
    # Trigger setters which apply to AudioServer
    audio_settings.master_volume = audio_settings.master_volume
    audio_settings.music_volume = audio_settings.music_volume
    audio_settings.sfx_volume = audio_settings.sfx_volume
    audio_settings.dialogue_volume = audio_settings.dialogue_volume
    audio_settings.ambience_volume = audio_settings.ambience_volume
    audio_settings.ui_volume = audio_settings.ui_volume

func get_audio_settings() -> AudioSettings:
    return audio_settings
```

### Volume Slider Control

```gdscript
# volume_slider.gd
extends HSlider

@export var bus_name: String = "Music"

func _ready() -> void:
    connect("value_changed", _on_value_changed)
    
    # Initialize from current bus volume
    var bus_idx := AudioServer.get_bus_index(bus_name)
    var current_db := AudioServer.get_bus_volume_db(bus_idx)
    value = _db_to_linear(current_db)

func _on_value_changed(value: float) -> void:
    var bus_idx := AudioServer.get_bus_index(bus_name)
    var db_value := _linear_to_db(value)
    AudioServer.set_bus_volume_db(bus_idx, db_value)
    
    # Save to settings
    SettingsManager.save_settings()

func _db_to_linear(db: float) -> float:
    # Convert dB to linear (0-1) for slider
    return pow(10.0, db / 20.0)

func _linear_to_db(linear: float) -> float:
    # Convert linear (0-1) to dB
    if linear <= 0.0:
        return -80.0
    return 20.0 * log10(linear)
```

---

## Audio Node Assignment

### Assigning Nodes to Buses

**Method 1: In Editor**
1. Select AudioStreamPlayer node
2. In Inspector, set `Bus` property to desired bus name
3. All audio from this node will route to the selected bus

**Method 2: In Code**
```gdscript
# Assign AudioStreamPlayer to Music bus
var music_player := AudioStreamPlayer.new()
add_child(music_player)

# Set bus by index
music_player.bus = AudioServer.get_bus_index("Music")

# Or set bus by name
music_player.bus = "Music"  # Godot resolves name to index
```

### Audio Node Configuration Patterns

**Music Player:**
```gdscript
# music_player.gd
@onready var stream_player: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
    stream_player.bus = "Music"
    stream_player.volume_db = 0.0  # Full volume (bus controls overall level)
    stream_player.loop = true

func play_track(track: AudioStream) -> void:
    stream_player.stream = track
    stream_player.play()

func stop() -> void:
    stream_player.stop()
```

**SFX Player (Pool Pattern):**
```gdscript
# sfx_pool.gd
extends Node

const POOL_SIZE := 16
var pool: Array[AudioStreamPlayer] = []

func _ready() -> void:
    for i in range(POOL_SIZE):
        var player := AudioStreamPlayer.new()
        player.bus = "SFX"
        player.volume_db = 0.0
        player.autoplay = false
        add_child(player)
        pool.append(player)
        player.finished.connect(_on_player_finished.bind(player))

func play_sfx(sfx: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
    for player in pool:
        if not player.playing:
            player.stream = sfx
            player.volume_db = volume_db
            player.pitch_scale = pitch
            player.play()
            return
    
    # All players busy - steal the oldest
    var oldest := pool[0]
    for player in pool:
        if player.get_stream_playback().time > oldest.get_stream_playback().time:
            oldest = player
    
    oldest.stop()
    oldest.stream = sfx
    oldest.volume_db = volume_db
    oldest.pitch_scale = pitch
    oldest.play()

func _on_player_finished(player: AudioStreamPlayer) -> void:
    # Player automatically stops, can be reused
    pass
```

**Dialogue Player:**
```gdscript
# dialogue_player.gd
extends Node

@onready var stream_player: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
    stream_player.bus = "Dialogue"
    stream_player.volume_db = 0.0

func play_line(audio_stream: AudioStream, on_finished: Callable = null) -> void:
    stream_player.stop()  # Stop any current dialogue
    stream_player.stream = audio_stream
    
    if on_finished:
        stream_player.finished.connect(on_finished, CONNECT_ONE_SHOT)
    
    stream_player.play()

func stop_current() -> void:
    stream_player.stop()
```

### Bus Assignment Helper

```gdscript
# audio_helper.gd

class_name AudioHelper

enum AudioBus { MASTER, MUSIC, SFX, DIALOGUE, AMBIENCE, UI }

static func get_bus_index(bus: AudioBus) -> int:
    match bus:
        AudioBus.MASTER:
            return AudioServer.get_bus_index("Master")
        AudioBus.MUSIC:
            return AudioServer.get_bus_index("Music")
        AudioBus.SFX:
            return AudioServer.get_bus_index("SFX")
        AudioBus.DIALOGUE:
            return AudioServer.get_bus_index("Dialogue")
        AudioBus.AMBIENCE:
            return AudioServer.get_bus_index("Ambience")
        AudioBus.UI:
            return AudioServer.get_bus_index("UI")

static func assign_to_bus(player: AudioStreamPlayer, bus: AudioBus) -> void:
    player.bus = get_bus_index(bus)

static func play_on_bus(sfx: AudioStream, bus: AudioBus, volume_db := 0.0) -> void:
    var player := AudioStreamPlayer.new()
    player.bus = get_bus_index(bus)
    player.stream = sfx
    player.volume_db = volume_db
    player.play()
    
    # Auto-queue for deletion after finishing
    player.finished.connect(player.queue_free)
    get_tree().root.add_child(player)
```

---

## Dynamic Audio Control

### Ducking (Volume Reduction)

**Concept**: Automatically lower one bus volume when another plays (e.g., lower music when dialogue plays)

```gdscript
# audio_ducking.gd
extends Node

@export var ducking_amount_db: float = -12.0
@export var fade_time_ms: float = 100.0

var is_ducked := false
var original_volume := 0.0

func _ready() -> void:
    # Listen for dialogue start
    DialogueManager.dialogue_started.connect(_on_dialogue_started)
    DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_dialogue_started() -> void:
    if is_ducked:
        return
    
    is_ducked = true
    var music_idx := AudioServer.get_bus_index("Music")
    original_volume = AudioServer.get_bus_volume_db(music_idx)
    
    # Fade out music
    var tween := create_tween()
    tween.tween_property(
        AudioServer,
        "bus/volume_db:Music",
        original_volume + ducking_amount_db,
        fade_time_ms / 1000.0
    )

func _on_dialogue_ended() -> void:
    if not is_ducked:
        return
    
    is_ducked = false
    var music_idx := AudioServer.get_bus_index("Music")
    
    # Fade in music
    var tween := create_tween()
    tween.tween_property(
        AudioServer,
        "bus/volume_db:Music",
        original_volume,
        fade_time_ms / 1000.0
    )
```

### Environment-Based Audio

```gdscript
# environment_audio.gd
extends Node

const ENVIRONMENT_EFFECTS := {
    "normal": {
        "ambience_bus": 0.0,
        "reverb_amount": 0.0,
        "low_pass": 22000.0
    },
    "cave": {
        "ambience_bus": 3.0,
        "reverb_amount": 0.5,
        "low_pass": 10000.0
    },
    "underwater": {
        "ambience_bus": 6.0,
        "reverb_amount": 0.3,
        "low_pass": 5000.0
    },
    "forest": {
        "ambience_bus": 0.0,
        "reverb_amount": 0.2,
        "low_pass": 22000.0
    }
}

func set_environment(environment: String) -> void:
    var config := ENVIRONMENT_EFFECTS.get(environment, ENVIRONMENT_EFFECTS["normal"])
    
    # Set ambience volume
    AudioServer.set_bus_volume_db(
        AudioServer.get_bus_index("Ambience"),
        config["ambience_bus"]
    )
    
    # Configure reverb on ambience bus
    _configure_reverb(config["reverb_amount"])
    
    # Configure low-pass filter on SFX bus
    _configure_low_pass(config["low_pass"])

func _configure_reverb(amount: float) -> void:
    var ambience_idx := AudioServer.get_bus_index("Ambience")
    
    # Remove existing reverb
    _remove_effects_of_type(ambience_idx, AudioEffectReverb)
    
    # Add new reverb
    if amount > 0:
        var reverb := AudioEffectReverb.new()
        reverb.room_size = amount
        reverb.damping = 0.5
        reverb.wet = amount
        reverb.dry = 1.0 - amount
        AudioServer.add_bus_effect(ambience_idx, reverb)

func _configure_low_pass(cutoff: float) -> void:
    var sfx_idx := AudioServer.get_bus_index("SFX")
    
    # Remove existing filter
    _remove_effects_of_type(sfx_idx, AudioEffectLowPassFilter)
    
    # Add new filter
    if cutoff < 22000:
        var filter := AudioEffectLowPassFilter.new()
        filter.cutoff_hz = cutoff
        AudioServer.add_bus_effect(sfx_idx, filter)

func _remove_effects_of_type(bus_idx: int, effect_type: String) -> void:
    var effect_count := AudioServer.get_bus_effect_count(bus_idx)
    for i in range(effect_count):
        var effect := AudioServer.get_bus_effect(bus_idx, i)
        if effect.get_class() == effect_type:
            AudioServer.remove_bus_effect(bus_idx, i)
            # Indexes shift after removal, so restart
            _remove_effects_of_type(bus_idx, effect_type)
            break
```

### Priority Audio (Blocking Cues)

**Concept**: Ensure critical SFX (combat hits, warnings) are always audible

```gdscript
# priority_audio.gd
extends Node

const PRIORITY_SFX := [
    "res://assets/audio/sfx/hit.ogg",
    "res://assets/audio/sfx/warning.ogg",
    "res://assets/audio/sfx/danger.ogg"
]

func play_priority_sfx(sfx_path: String, volume_db := 0.0) -> void:
    # Temporarily duck music and ambience
    _duck_non_essential()
    
    # Play the SFX
    var player := AudioStreamPlayer.new()
    player.bus = AudioServer.get_bus_index("SFX")
    player.stream = preload(sfx_path)
    player.volume_db = volume_db + 3.0  # Boost priority SFX by 3dB
    player.play()
    add_child(player)
    
    # Unduck after SFX finishes
    player.finished.connect(_unduck_non_essential.bind(player))

func _duck_non_essential() -> void:
    # Duck music and ambience
    var music_idx := AudioServer.get_bus_index("Music")
    var ambience_idx := AudioServer.get_bus_index("Ambience")
    
    AudioServer.set_bus_volume_db(music_idx, AudioServer.get_bus_volume_db(music_idx) - 12.0)
    AudioServer.set_bus_volume_db(ambience_idx, AudioServer.get_bus_volume_db(ambience_idx) - 12.0)

func _unduck_non_essential(player: AudioStreamPlayer) -> void:
    # Restore original volumes
    var music_idx := AudioServer.get_bus_index("Music")
    var ambience_idx := AudioServer.get_bus_index("Ambience")
    
    # Note: In real implementation, store original volumes
    AudioServer.set_bus_volume_db(music_idx, -6.0)  # Default music volume
    AudioServer.set_bus_volume_db(ambience_idx, -3.0)  # Default ambience volume
    
    player.queue_free()
```

---

## Accessibility & Child-Safety

### Child-Safe Audio Guidelines

**Volume Balance:**
```
Master:  0 dB (reference)
Dialogue: 0 dB (clearly audible)
Music:   -6 dB (subdued, doesn't compete)
SFX:     0 dB (audible but not overpowering)
Ambience:-3 dB (subtle background)
UI:      0 dB (clear but not distracting)
```

**DO:**
- ✅ Keep music volume below dialogue
- ✅ Use gentle fades for transitions
- ✅ Limit maximum volume to prevent startling
- ✅ Test on laptop speakers (target hardware)
- ✅ Provide volume controls for each bus
- ✅ Make critical SFX clearly distinct

**DON'T:**
- ❌ Sudden loud noises
- ❌ Rapid volume changes
- ❌ Music louder than dialogue
- ❌ SFX that mask important cues
- ❌ High-pitched tones that could hurt ears

### Audio Settings UI

```gdscript
# audio_settings_panel.gd
extends Panel

@onready var master_slider: VolumeSlider
@onready var music_slider: VolumeSlider
@onready var sfx_slider: VolumeSlider
@onready var dialogue_slider: VolumeSlider
@onready var ambience_slider: VolumeSlider
@onready var ui_slider: VolumeSlider

func _ready() -> void:
    # Initialize sliders
    master_slider.bus_name = "Master"
    music_slider.bus_name = "Music"
    sfx_slider.bus_name = "SFX"
    dialogue_slider.bus_name = "Dialogue"
    ambience_slider.bus_name = "Ambience"
    ui_slider.bus_name = "UI"

func reset_to_defaults() -> void:
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), 0.0)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -6.0)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), 0.0)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Dialogue"), 0.0)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), -3.0)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("UI"), 0.0)
    
    # Update sliders to match
    master_slider.value = 1.0  # 0dB
    music_slider.value = 0.5   # -6dB
    sfx_slider.value = 1.0     # 0dB
    dialogue_slider.value = 1.0
    ambience_slider.value = 0.7  # -3dB
    ui_slider.value = 1.0
    
    SettingsManager.save_settings()
```

---

## Integration with Other Systems

### Integration with PLAN-012 (Continuous Exploration Music)

```gdscript
# music_manager.gd (updated)

func _ready() -> void:
    # Assign to Music bus
    current_player.bus = AudioServer.get_bus_index("Music")
    next_player.bus = AudioServer.get_bus_index("Music")
    
    # Volume controlled by bus, so individual players at 0dB
    current_player.volume_db = 0.0
    next_player.volume_db = -80.0  # Muted initially
```

### Integration with VS-015 (Cinematic Acting Voice)

```gdscript
# voice_manager.gd

func play_voice_line(audio_stream: AudioStream, character: String) -> void:
    var player := AudioStreamPlayer.new()
    player.bus = AudioServer.get_bus_index("Dialogue")
    player.stream = audio_stream
    player.volume_db = 0.0
    player.play()
    add_child(player)
    
    # Auto-cleanup
    player.finished.connect(player.queue_free)
    
    # Duck music while dialogue plays
    AudioDucking.duck_for_dialogue()
    player.finished.connect(AudioDucking.unduck_for_dialogue)
```

### Integration with PLAN-005 (Combat Feel & Feedback)

```gdscript
# combat_audio.gd

func play_hit_sfx() -> void:
    # Use priority audio for hit sounds
    PriorityAudio.play_priority_sfx("res://assets/audio/combat/hit.ogg")

func play_weapon_swing() -> void:
    # Regular SFX
    AudioHelper.play_on_bus(
        preload("res://assets/audio/combat/swing.ogg"),
        AudioHelper.AudioBus.SFX,
        -2.0  # Slightly quieter
    )
```

---

## Code Samples & Implementation Patterns

### Complete Audio Manager

```gdscript
# audio_manager.gd - Singleton
extends Node

const BUS_NAMES := ["Master", "Music", "SFX", "Dialogue", "Ambience", "UI"]

@onready var settings: AudioSettings

func _ready() -> void:
    _initialize_buses()
    _initialize_settings()

func _initialize_buses() -> void:
    # Create buses
    AudioServer.set_bus_count(BUS_NAMES.size())
    
    for i in BUS_NAMES.size():
        AudioServer.set_bus_name(i, BUS_NAMES[i])
    
    # Configure sends (all to Master)
    for i in range(1, BUS_NAMES.size()):
        AudioServer.set_bus_send(i, 0)  # Send to Master (index 0)
    
    # Set default volumes
    AudioServer.set_bus_volume_db(0, 0.0)      # Master
    AudioServer.set_bus_volume_db(1, -6.0)    # Music
    AudioServer.set_bus_volume_db(2, 0.0)      # SFX
    AudioServer.set_bus_volume_db(3, 0.0)      # Dialogue
    AudioServer.set_bus_volume_db(4, -3.0)    # Ambience
    AudioServer.set_bus_volume_db(5, 0.0)      # UI
    
    # Add effects
    _setup_master_effects()
    _setup_music_effects()
    _setup_sfx_effects()
    _setup_dialogue_effects()
    _setup_ambience_effects()
    _setup_ui_effects()

func _setup_master_effects() -> void:
    var master_idx := AudioServer.get_bus_index("Master")
    # Limiter on Master for peak protection
    var limiter := AudioEffectLimiter.new()
    limiter.threshold_db = -1.0
    limiter.release_ms = 5.0
    AudioServer.add_bus_effect(master_idx, limiter)

func _setup_music_effects() -> void:
    var music_idx := AudioServer.get_bus_index("Music")
    # EQ for warm tone
    var eq := AudioEffectEQ10.new()
    eq.set_band_gain_db(0, 3.0)
    eq.set_band_gain_db(1, 2.0)
    eq.set_band_gain_db(8, -2.0)
    eq.set_band_gain_db(9, -3.0)
    AudioServer.add_bus_effect(music_idx, eq)
    
    # Gentle compression
    var compressor := AudioEffectCompressor.new()
    compressor.threshold_db = -20.0
    compressor.ratio = 2.0
    compressor.attack_us = 10000
    compressor.release_ms = 100
    AudioServer.add_bus_effect(music_idx, compressor)

func _setup_sfx_effects() -> void:
    var sfx_idx := AudioServer.get_bus_index("SFX")
    # EQ for clarity
    var eq := AudioEffectEQ10.new()
    eq.set_band_gain_db(2, 2.0)   # Boost 125Hz for impact
    eq.set_band_gain_db(4, 2.0)   # Boost 500Hz for clarity
    AudioServer.add_bus_effect(sfx_idx, eq)
    
    # Moderate compression
    var compressor := AudioEffectCompressor.new()
    compressor.threshold_db = -15.0
    compressor.ratio = 3.0
    compressor.attack_us = 5000
    compressor.release_ms = 50
    AudioServer.add_bus_effect(sfx_idx, compressor)
    
    # Limiter for protection
    var limiter := AudioEffectLimiter.new()
    limiter.threshold_db = -3.0
    AudioServer.add_bus_effect(sfx_idx, limiter)

func _setup_dialogue_effects() -> void:
    var dialogue_idx := AudioServer.get_bus_index("Dialogue")
    # Aggressive compression for clarity
    var compressor := AudioEffectCompressor.new()
    compressor.threshold_db = -24.0
    compressor.ratio = 4.0
    compressor.attack_us = 1000
    compressor.release_ms = 20
    compressor.makeup_gain_db = 3.0
    AudioServer.add_bus_effect(dialogue_idx, compressor)
    
    # Limiter
    var limiter := AudioEffectLimiter.new()
    limiter.threshold_db = -3.0
    AudioServer.add_bus_effect(dialogue_idx, limiter)

func _setup_ambience_effects() -> void:
    var ambience_idx := AudioServer.get_bus_index("Ambience")
    # EQ for atmosphere
    var eq := AudioEffectEQ10.new()
    eq.set_band_gain_db(0, 2.0)
    eq.set_band_gain_db(1, 1.5)
    AudioServer.add_bus_effect(ambience_idx, eq)
    
    # Subtle reverb
    var reverb := AudioEffectReverb.new()
    reverb.room_size = 0.3
    reverb.damping = 0.5
    reverb.wet = 0.3
    reverb.dry = 0.7
    AudioServer.add_bus_effect(ambience_idx, reverb)

func _setup_ui_effects() -> void:
    var ui_idx := AudioServer.get_bus_index("UI")
    # Limiter for protection
    var limiter := AudioEffectLimiter.new()
    limiter.threshold_db = -3.0
    AudioServer.add_bus_effect(ui_idx, limiter)

func _initialize_settings() -> void:
    settings = AudioSettings.new()
    settings.master_volume = 0.0
    settings.music_volume = -6.0
    settings.sfx_volume = 0.0
    settings.dialogue_volume = 0.0
    settings.ambience_volume = -3.0
    settings.ui_volume = 0.0

# Public API
func get_bus_index(bus_name: String) -> int:
    return AudioServer.get_bus_index(bus_name)

func set_bus_volume(bus_name: String, volume_db: float) -> void:
    AudioServer.set_bus_volume_db(get_bus_index(bus_name), volume_db)

func get_bus_volume(bus_name: String) -> float:
    return AudioServer.get_bus_volume_db(get_bus_index(bus_name))

func set_bus_mute(bus_name: String, mute: bool) -> void:
    AudioServer.set_bus_mute(get_bus_index(bus_name), mute)

func is_bus_mute(bus_name: String) -> bool:
    return AudioServer.is_bus_mute(get_bus_index(bus_name))
```

### Bus Volume Fader

```gdscript
# bus_fader.gd
extends Node

signal fade_completed(bus_name: String, target_volume: float)

func fade_bus_to(bus_name: String, target_volume_db: float, duration: float) -> void:
    var bus_idx := AudioServer.get_bus_index(bus_name)
    var current_volume := AudioServer.get_bus_volume_db(bus_idx)
    
    var tween := create_tween()
    tween.tween_property(
        AudioServer,
        "bus/volume_db:" + bus_name,
        target_volume_db,
        duration
    )
    
    await tween.finished
    emit_signal("fade_completed", bus_name, target_volume_db)

func fade_bus_by(bus_name: String, delta_db: float, duration: float) -> void:
    var bus_idx := AudioServer.get_bus_index(bus_name)
    var current_volume := AudioServer.get_bus_volume_db(bus_idx)
    fade_bus_to(bus_name, current_volume + delta_db, duration)
```

---

## Testing & Validation Checklist

### Bus Configuration Tests

- [ ] All buses created with correct names
- [ ] All buses route to Master
- [ ] Default volumes set correctly
- [ ] No buses muted by default
- [ ] Bus count matches expected (6)

### Effect Configuration Tests

- [ ] Master bus has limiter
- [ ] Music bus has EQ and compressor
- [ ] SFX bus has EQ, compressor, and limiter
- [ ] Dialogue bus has compressor and limiter
- [ ] Ambience bus has EQ and reverb
- [ ] UI bus has limiter
- [ ] Effects are in correct order

### Audio Routing Tests

- [ ] Music player uses Music bus
- [ ] SFX players use SFX bus
- [ ] Voice lines use Dialogue bus
- [ ] Ambience uses Ambience bus
- [ ] UI sounds use UI bus
- [ ] All audio eventually reaches Master

### Volume Tests

- [ ] Music volume is -6dB (below dialogue)
- [ ] Dialogue is audible over music
- [ ] SFX are clear and audible
- [ ] Critical SFX cut through music (priority)
- [ ] No audio clipping or distortion
- [ ] Volume sliders work for each bus

### Ducking Tests

- [ ] Music ducks when dialogue plays
- [ ] Music restores after dialogue ends
- [ ] Ducking is smooth (fade in/out)
- [ ] Ducking amount is appropriate (-12dB)

### Environment Tests

- [ ] Normal environment: no effects
- [ ] Cave environment: reverb on ambience
- [ ] Underwater: low-pass filter on SFX
- [ ] Environment transitions are smooth

### Child-Safety Tests

- [ ] Music never overpowers dialogue
- [ ] No startling loud noises
- [ ] Volume balance is appropriate
- [ ] Audio is clear on laptop speakers
- [ ] Settings can be adjusted by parents

### Performance Tests

- [ ] No frame drops with audio effects
- [ ] Memory usage is stable
- [ ] Loading times are acceptable
- [ ] Multiple audio sources don't cause issues

### Stress Tests

- [ ] All buses active simultaneously
- [ ] Rapid bus volume changes
- [ ] Many SFX playing at once
- [ ] Long playback sessions (30+ minutes)

---

## Learning Resources

### Official Godot Documentation

- [Audio Buses](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html) - Official bus tutorial
- [Audio Effects](https://docs.godotengine.org/en/stable/tutorials/audio/audio_effects.html) - Effect documentation
- [AudioServer](https://docs.godotengine.org/en/stable/classes/class_audioserver.html) - AudioServer class reference
- [AudioStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html) - Player node reference

### Tutorials and Guides

- [Godot Audio Bus Setup](https://skills.rest/skill/godot-setup-audio-buses) - Automated bus setup
- [Sound Design with Godot AudioBus Effects](https://uhiyama-lab.com/en/notes/godot/audio-effects-sound-design/) - Effect configuration
- [GDQuest Audio System](https://www.gdquest.com/tutorial/godot/audio/) - Comprehensive audio tutorial
- [Inglo Games Audio Buses](https://inglo-games.github.io/2020/04/22/audio-busses.html) - Bus usage patterns

### Community Resources

- [r/godot - Audio Questions](https://www.reddit.com/r/godot/search/?q=audio) - Audio discussions
- [Godot Forum - Audio Section](https://forum.godotengine.org/c/audio/14) - Official audio forum
- [Audio Mixing Best Practices](https://app.studyraid.com/en/read/32761/1441906/setting-up-audio-buses-for-volume-control) - Volume control guide

### Tools

- [Audio Test Scene](https://github.com/godotengine/godot-demo-projects/tree/master/audio) - Godot demo audio project
- [Godot Audio Analyzer](https://github.com/alessandrofama/GodotAudioAnalyzer) - Audio visualization

---

## Summary

This research compendium provides a comprehensive guide to implementing a **complete audio bus architecture** in Godot 4.x for the Choyce Engine.

**Key Takeaways:**

1. **Bus Structure**: Master, Music (-6dB), SFX (0dB), Dialogue (0dB), Ambience (-3dB), UI (0dB)
2. **Effect Chains**: EQ → Compressor → Reverb → Limiter (per bus as needed)
3. **Volume Management**: Centralized settings with per-bus control
4. **Dynamic Control**: Ducking, environment effects, priority audio
5. **Child-Safety**: Music < Dialogue, no startling sounds, clear audio
6. **Integration**: Works with PLAN-012 (music), VS-015 (voice), PLAN-005 (combat)

**Implementation Order:**
1. Configure buses in Project Settings
2. Add effects to each bus
3. Implement settings system
4. Assign audio nodes to buses
5. Add dynamic controls (ducking, environment)
6. Test thoroughly
7. Integrate with existing systems

This audio bus architecture forms the foundation for all audio in Choyce Engine, ensuring consistent, high-quality, child-safe sound throughout the game.

---

*Generated for Choyce Engine - PLAN-014 Audio Bus Architecture*
*Last updated: 2026-07-18*
