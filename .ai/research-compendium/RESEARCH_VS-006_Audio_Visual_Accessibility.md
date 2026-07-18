# VS-006: Audio, Visual & Accessibility Quality - Deep Research Compendium

**Status**: in_progress  
**Specialty**: presentation-qa  
**Owner**: mistral  
**Cross-review**: copilot  
**Priority**: HIGH  
**Last Updated**: 2026-07-18

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Current Implementation Status](#current-implementation-status)
3. [Godot 4.6 Audio System Deep Dive](#godot-46-audio-system-deep-dive)
4. [Audio Bus Architecture & Mixing](#audio-bus-architecture--mixing)
5. [Compression & Ducking Systems](#compression--ducking-systems)
6. [Accessibility Implementation](#accessibility-implementation)
7. [Caption & Subtitle Systems](#caption--subtitle-systems)
8. [Performance Optimization](#performance-optimization)
9. [Code Samples & Implementation Patterns](#code-samples--implementation-patterns)
10. [Asset Sources & Licensing](#asset-sources--licensing)
11. [Best Practices & Standards Compliance](#best-practices--standards-compliance)
12. [Testing & Validation Checklist](#testing--validation-checklist)
13. [Learning Resources](#learning-resources)

---

## Task Overview

### Objective

Certify rendered audio, visual, and accessibility quality for the Choyce Engine Adventure slice. This encompasses:

- **Audio System**: Complete bus architecture with proper mixing, ducking, and dynamic range control
- **Accessibility**: WCAG 2.2 AA compliance including reduce-motion, captions, and screen reader support
- **Quality Assurance**: Manual QA evidence, performance measurements, and triage reporting
- **Platform Support**: Tier 1 and Tier 2 hardware validation

### Acceptance Criteria (from backlog.yaml)

- [ ] Screenshots and performance evidence exist for Tier 1 and Tier 2
- [ ] Audio buses, levels, blocking cues, captions, and reduce-motion are checked
- [ ] Findings are triaged with explicit release recommendation

### Dependencies

- VS-004 (Repository truth gate)

---

## Current Implementation Status

### Existing Code & Evidence

Based on backlog.yaml evidence section:

```
├── src/adapters/inbound/shared/audio/
│   ├── bus_setup.gd           # Runtime bus creation
│   ├── bus_setup.tscn         # Bus setup scene
│   └── audio_bank.gd         # Players assigned to Music/Voice/SFX buses
├── src/ports/outbound/
│   └── accessibility_policy_port.gd  # Added set_reduce_motion/is_reduce_motion_enabled
├── src/adapters/outbound/
│   └── godot_accessibility_adapter.gd  # Implemented reduce-motion support
├── src/adapters/inbound/gameplay/
│   ├── screen_feedback.gd     # shake/shake_directional respect reduce-motion
│   ├── effect_spawner.gd     # All particle effects respect reduce-motion
│   └── gameplay_runtime.gd    # Ambient particles respect reduce-motion
└── manual-qa/VS-006/
    ├── REPORT.md              # Comprehensive QA report with triage
    └── audio_analysis.sh       # Automated analysis script
```

### Current Gaps Identified

1. **Audio Bus Architecture**: Need Godot 4.6 specific implementation patterns
2. **Compressor Configuration**: Need optimal settings for Music/SFX/Voice buses
3. **Ducking System**: Need sidechain compression implementation
4. **Accessibility API**: Need platform-specific reduce-motion detection
5. **Caption System**: Need robust subtitle display and timing
6. **Performance Validation**: Need Tier 1/Tier 2 measurement methodology

---

## Godot 4.6 Audio System Deep Dive

### Audio Server Architecture

Godot 4.6 uses a hierarchical audio bus system with the following key components:

```
Master Bus (Output)
├── Music Bus
│   ├── Compressor (for dynamic control)
│   └── Limiter (final output protection)
├── Voice Bus
│   └── Compressor (consistent levels)
├── SFX Bus
│   └── EQ/Reverb (optional)
└── UI Bus
    └── (Dry, no effects)
```

### Audio Node Hierarchy

```
AudioStreamPlayer    # For 2D sounds (UI, ambient)
AudioStreamPlayer3D  # For spatial audio (positional)
├── bus             # Assign to specific bus
├── volume_db       # Individual volume
├── pitch_scale     # Playback speed
├── autoplay        # Auto-start on ready
└── stream          # AudioStream resource
```

### AudioStream Formats

| Format | Use Case | Compression | Quality | Godot Support |
|--------|----------|-------------|---------|----------------|
| WAV | Short SFX, UI | None | Lossless | Native |
| OGG Vorbis | Music, long SFX | Lossy | High | Native |
| MP3 | Legacy compatibility | Lossy | Medium | Via plugin |
| FLAC | High-quality music | Lossless | High | Native |

**Recommendation**: Use WAV for SFX < 5s, OGG for music and long sounds

---

## Audio Bus Architecture & Mixing

### Bus Configuration (Project Settings > Audio > Buses)

#### Recommended Bus Structure

| Bus Name | Default Volume (dB) | Purpose | Effects |
|----------|---------------------|---------|---------|
| Master | 0.0 | Final output | Limiter | 
| Music | -6.0 | Background music | Compressor, Reverb |
| Voice | 0.0 | Dialogue, narration | Compressor, EQ |
| SFX | 0.0 | Sound effects | Compressor |
| UI | 0.0 | Interface sounds | None |
| Ambient | -12.0 | Environmental sounds | Reverb |

#### Bus Setup Code (bus_setup.gd)

```gdscript
# bus_setup.gd - Runtime bus configuration
extends Node

func _ready() -> void:
    # Ensure buses exist (create if missing)
    _ensure_bus("Music", -6.0)
    _ensure_bus("Voice", 0.0)
    _ensure_bus("SFX", 0.0)
    _ensure_bus("UI", 0.0)
    _ensure_bus("Ambient", -12.0)
    
    # Configure effects on each bus
    _configure_music_bus()
    _configure_voice_bus()
    _configure_sfx_bus()

func _ensure_bus(bus_name: String, default_volume_db: float) -> void:
    if not AudioServer.bus_exists(bus_name):
        AudioServer.add_bus(bus_name)
    
    var index := AudioServer.get_bus_index(bus_name)
    AudioServer.set_bus_volume_db(index, default_volume_db)

func _configure_music_bus() -> void:
    var index := AudioServer.get_bus_index("Music")
    
    # Add compressor for dynamic control
    var compressor := AudioEffectCompressor.new()
    compressor.threshold_db = -12.0
    compressor.ratio = 2.0
    compressor.attack_sec = 0.1
    compressor.release_sec = 0.3
    compressor.makeup_gain_db = 2.0
    
    AudioServer.add_bus_effect(index, compressor)
    
    # Add limiter for final protection
    var limiter := AudioEffectLimiter.new()
    limiter.threshold_db = -3.0
    limiter.soft_clip = true
    
    AudioServer.add_bus_effect(index, limiter)

func _configure_voice_bus() -> void:
    var index := AudioServer.get_bus_index("Voice")
    
    # Voice needs faster, more aggressive compression
    var compressor := AudioEffectCompressor.new()
    compressor.threshold_db = -24.0
    compressor.ratio = 4.0
    compressor.attack_sec = 0.01
    compressor.release_sec = 0.05
    compressor.makeup_gain_db = 3.0
    
    AudioServer.add_bus_effect(index, compressor)

func _configure_sfx_bus() -> void:
    var index := AudioServer.get_bus_index("SFX")
    
    # SFX gets moderate compression
    var compressor := AudioEffectCompressor.new()
    compressor.threshold_db = -18.0
    compressor.ratio = 3.0
    compressor.attack_sec = 0.05
    compressor.release_sec = 0.1
    
    AudioServer.add_bus_effect(index, compressor)
```

### Volume Management Utilities

```gdscript
# audio_utils.gd - Utility functions for audio management

class_name AudioUtils

# Convert linear volume (0-1) to decibels
static func linear_to_db(linear: float) -> float:
    return linear_to_db(linear) if linear > 0.0001 else -80.0

# Convert decibels to linear volume (0-1)
static func db_to_linear(db: float) -> float:
    return db_to_linear(db)

# Fade bus volume over time
static func fade_bus_volume(bus_name: String, target_db: float, duration: float) -> void:
    var index := AudioServer.get_bus_index(bus_name)
    var current_db := AudioServer.get_bus_volume_db(index)
    
    var tween := create_tween()
    tween.tween_property(
        AudioServer,
        "bus_volume_db:%d" % index,
        target_db,
        duration
    )

# Set bus volume with optional fade
static func set_bus_volume(bus_name: String, volume_db: float, fade_duration: float = 0.0) -> void:
    var index := AudioServer.get_bus_index(bus_name)
    
    if fade_duration > 0:
        var tween := create_tween()
        tween.tween_property(
            AudioServer,
            "bus_volume_db:%d" % index,
            volume_db,
            fade_duration
        )
    else:
        AudioServer.set_bus_volume_db(index, volume_db)
```

---

## Compression & Ducking Systems

### AudioEffectCompressor Parameters (Godot 4.6)

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| threshold_db | float | -60 to 0 | -20.0 | Level (dB) where compression starts |
| ratio | float | 1 to 48 | 4.0 | Compression ratio (4:1 = 4dB in → 1dB out) |
| attack_sec | float | 0.00002 to 2 | 0.01 | Time to react to threshold breach |
| release_sec | float | 0.00002 to 2 | 0.1 | Time to stop compressing after signal drops |
| knee_db | float | 0 to 48 | 6.0 | Smooth transition range above threshold |
| makeup_gain_db | float | -40 to 40 | 0.0 | Gain boost to compensate volume loss |
| sidechain_bus | String | - | "" | Bus name for sidechain input |
| sidechain_invert | bool | - | false | Invert sidechain signal |
| sidechain_mix | float | 0 to 1 | 1.0 | Sidechain signal mix amount |

### Preset Configurations

#### Music Bus (Gentle Glue Compression)
```gdscript
compressor.threshold_db = -12.0
compressor.ratio = 2.0
compressor.attack_sec = 0.1
compressor.release_sec = 0.3
compressor.knee_db = 6.0
compressor.makeup_gain_db = 2.0
```

#### Voice Bus (Aggressive Leveling)
```gdscript
compressor.threshold_db = -24.0
compressor.ratio = 6.0
compressor.attack_sec = 0.01
compressor.release_sec = 0.05
compressor.knee_db = 3.0
compressor.makeup_gain_db = 3.0
```

#### SFX Bus (Moderate Control)
```gdscript
compressor.threshold_db = -18.0
compressor.ratio = 4.0
compressor.attack_sec = 0.05
compressor.release_sec = 0.1
compressor.knee_db = 4.0
compressor.makeup_gain_db = 1.0
```

### Sidechain Ducking Implementation

#### Method 1: Automatic Sidechain Compression

```gdscript
# Configure Music bus to duck when Voice plays
func configure_voice_ducking() -> void:
    var music_index := AudioServer.get_bus_index("Music")
    
    # Get or create the compressor effect
    if AudioServer.get_bus_effect_count(music_index) == 0:
        var compressor := AudioEffectCompressor.new()
        AudioServer.add_bus_effect(music_index, compressor)
    
    var compressor := AudioServer.get_bus_effect(music_index, 0)
    
    # Configure for ducking
    compressor.sidechain_bus = "Voice"
    compressor.threshold_db = -30.0  # Voice triggers at -30dB
    compressor.ratio = 8.0           # Strong ducking ratio
    compressor.attack_sec = 0.01     # Fast attack
    compressor.release_sec = 0.2    # Moderate release
    compressor.makeup_gain_db = 0.0  # No makeup gain for ducking
```

#### Method 2: Manual Bus Volume Ducking

```gdscript
# audio_ducker.gd - Manual ducking system

class_name AudioDucker

export var music_bus: String = "Music"
export var voice_bus: String = "Voice"
export var duck_amount_db: float = -12.0
export var fade_duration: float = 0.2

var voice_playing_count: int = 0
var original_music_volume: float = 0.0

func _ready() -> void:
    # Store original volume
    var music_index := AudioServer.get_bus_index(music_bus)
    original_music_volume = AudioServer.get_bus_volume_db(music_index)

func register_voice_player() -> void:
    voice_playing_count += 1
    if voice_playing_count == 1:
        _apply_ducking()

func unregister_voice_player() -> void:
    voice_playing_count = max(0, voice_playing_count - 1)
    if voice_playing_count == 0:
        _remove_ducking()

func _apply_ducking() -> void:
    var music_index := AudioServer.get_bus_index(music_bus)
    AudioUtils.fade_bus_volume(music_bus, original_music_volume + duck_amount_db, fade_duration)

func _remove_ducking() -> void:
    var music_index := AudioServer.get_bus_index(music_bus)
    AudioUtils.fade_bus_volume(music_bus, original_music_volume, fade_duration)

# Usage in AudioStreamPlayer
func _on_finished() -> void:
    AudioDucker.unregister_voice_player()
```

#### Method 3: Hybrid Approach (Recommended)

```gdscript
# audio_manager.gd - Hybrid ducking with sidechain + manual override

class_name AudioManager

export var enable_automatic_ducking: bool = true
export var enable_manual_ducking: bool = true

var voice_active: bool = false

func _ready() -> void:
    if enable_automatic_ducking:
        _setup_sidechain_ducking()

func _setup_sidechain_ducking() -> void:
    var music_index := AudioServer.get_bus_index("Music")
    
    # Clear existing effects
    while AudioServer.get_bus_effect_count(music_index) > 0:
        AudioServer.remove_bus_effect(music_index, 0)
    
    # Add sidechain compressor
    var compressor := AudioEffectCompressor.new()
    compressor.sidechain_bus = "Voice"
    compressor.threshold_db = -30.0
    compressor.ratio = 4.0
    compressor.attack_sec = 0.02
    compressor.release_sec = 0.3
    
    AudioServer.add_bus_effect(music_index, compressor)

func set_voice_active(active: bool) -> void:
    voice_active = active
    
    if enable_manual_ducking and not enable_automatic_ducking:
        var target_db := -12.0 if active else 0.0
        AudioUtils.fade_bus_volume("Music", target_db, 0.3)

func toggle_mute_bus(bus_name: String, muted: bool) -> void:
    var index := AudioServer.get_bus_index(bus_name)
    AudioServer.set_bus_mute(index, muted)

func toggle_solo_bus(bus_name: String, solo: bool) -> void:
    # Mute all buses except the soloed one
    for bus_name_iter in AudioServer.get_bus_names():
        var index := AudioServer.get_bus_index(bus_name_iter)
        if solo and bus_name_iter != bus_name:
            AudioServer.set_bus_mute(index, true)
        else:
            AudioServer.set_bus_mute(index, false)
```

---

## Accessibility Implementation

### Reduce Motion System

#### Implementation Approach

Since Godot 4.6 does not expose system-level "reduce motion" settings directly through AccessKit, we implement a layered approach:

1. **Engine-Level Setting**: Global configuration in ProjectSettings
2. **User Preference**: Saved in user configuration file
3. **System Detection**: Platform-specific APIs via GDExtension (optional)

#### Accessibility Policy Port

```gdscript
# src/ports/outbound/accessibility_policy_port.gd

class_name AccessibilityPolicyPort

export var default_reduce_motion: bool = false
export var default_caption_enabled: bool = true
export var default_caption_size: int = 1  # 0=Small, 1=Medium, 2=Large

var reduce_motion_enabled: bool = false
var captions_enabled: bool = true
var caption_size: int = 1

# Called during initialization
func initialize() -> void:
    _load_from_config()

func _load_from_config() -> void:
    var config := ConfigFile.new()
    var err := config.load("user://accessibility.cfg")
    
    if err == OK:
        reduce_motion_enabled = config.get_bool("accessibility", "reduce_motion", default_reduce_motion)
        captions_enabled = config.get_bool("accessibility", "captions_enabled", default_caption_enabled)
        caption_size = config.get_int("accessibility", "caption_size", default_caption_size)
    else:
        reduce_motion_enabled = default_reduce_motion
        captions_enabled = default_caption_enabled
        caption_size = default_caption_size

func _save_to_config() -> void:
    var config := ConfigFile.new()
    
    config.set_bool("accessibility", "reduce_motion", reduce_motion_enabled)
    config.set_bool("accessibility", "captions_enabled", captions_enabled)
    config.set_int("accessibility", "caption_size", caption_size)
    
    config.save("user://accessibility.cfg")

# Public API
func is_reduce_motion_enabled() -> bool:
    return reduce_motion_enabled

func set_reduce_motion_enabled(enabled: bool) -> void:
    reduce_motion_enabled = enabled
    _save_to_config()
    _notify_change()

func are_captions_enabled() -> bool:
    return captions_enabled

func set_captions_enabled(enabled: bool) -> void:
    captions_enabled = enabled
    _save_to_config()
    _notify_change()

func get_caption_size() -> int:
    return caption_size

func set_caption_size(size: int) -> void:
    caption_size = clamp(size, 0, 2)
    _save_to_config()
    _notify_change()

func _notify_change() -> void:
    # Emit signal or notify subscribers
    if has_method("_on_accessibility_changed"):
        _on_accessibility_changed()
```

#### Godot Accessibility Adapter

```gdscript
# src/adapters/outbound/godot_accessibility_adapter.gd

class_name GodotAccessibilityAdapter
extends AccessibilityPolicyPort

# Override to provide Godot-specific implementation
func initialize() -> void:
    super()
    
    # Connect to accessibility signals if available
    # Note: Godot 4.5+ AccessKit integration is automatic for Control nodes
    # We extend it with our custom settings
    
    # Check for system-level reduce motion (platform-specific)
    _check_system_reduce_motion()

func _check_system_reduce_motion() -> void:
    # Platform-specific detection
    # This would be implemented via GDExtension for best results
    
    # For now, use OS.has_feature as fallback (may not be available in 4.6)
    if OS.has_feature("Accessibility", "reduce_motion"):
        reduce_motion_enabled = true
    
    # macOS: Can use AppleScript or system APIs
    # Windows: Can use registry or WinAPI
    # Linux: Can check dconf/gsettings

# Utility for checking at runtime
func should_reduce_motion() -> bool:
    return is_reduce_motion_enabled()

func should_show_captions() -> bool:
    return are_captions_enabled()
```

### Reduce Motion in Practice

#### Camera Shake System

```gdscript
# src/adapters/inbound/gameplay/screen_feedback.gd

class_name ScreenFeedback
extends Node

@export var shake_intensity: float = 0.1
@export var shake_duration: float = 0.5

var current_shake: float = 0.0
var shake_timer: float = 0.0

func shake(intensity: float = -1.0, duration: float = -1.0) -> void:
    if GodotAccessibilityAdapter.should_reduce_motion():
        return  # Skip shake if reduce motion enabled
    
    current_shake = intensity if intensity >= 0 else shake_intensity
    shake_timer = duration if duration >= 0 else shake_duration

func shake_directional(direction: Vector2, intensity: float = -1.0, duration: float = -1.0) -> void:
    if GodotAccessibilityAdapter.should_reduce_motion():
        return
    
    # Implement directional shake logic
    current_shake = intensity if intensity >= 0 else shake_intensity
    shake_timer = duration if duration >= 0 else shake_duration

func _process(delta: float) -> void:
    if current_shake > 0:
        shake_timer -= delta
        if shake_timer <= 0:
            current_shake = 0.0
        else:
            # Apply shake to camera
            pass
```

#### Particle Effects System

```gdscript
# src/adapters/inbound/gameplay/effect_spawner.gd

class_name EffectSpawner
extends Node3D

@export var effect_scene: PackedScene
@export var spawn_on_start: bool = false

func _ready() -> void:
    if spawn_on_start:
        spawn()

func spawn(position: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> Node3D:
    if GodotAccessibilityAdapter.should_reduce_motion():
        return null  # Skip particle effects
    
    var effect := effect_scene.instantiate()
    effect.position = position
    effect.scale = scale
    add_child(effect)
    return effect

func spawn_simple() -> Node3D:
    return spawn()
```

#### Animation Player Wrapper

```gdscript
# src/adapters/inbound/gameplay/accessible_animation_player.gd

class_name AccessibleAnimationPlayer
extends AnimationPlayer

# Override play to respect reduce motion
func play(name: String = "", custom_speed: float = 1.0, from_end: bool = false, backward: bool = false, custom_blend: float = -1.0, custom_transition: float = -1.0) -> void:
    if GodotAccessibilityAdapter.should_reduce_motion():
        # Play reduced version or skip
        var reduced_name := name + "_reduced"
        if has_animation(reduced_name):
            super.play(reduced_name, custom_speed, from_end, backward, custom_blend, custom_transition)
        # else: skip animation
        return
    
    super.play(name, custom_speed, from_end, backward, custom_blend, custom_transition)

# For simple animations, provide reduced alternatives
func ensure_reduced_animations() -> void:
    var anims := get_animation_list()
    for anim_name in anims:
        if not anim_name.ends_with("_reduced"):
            # Create reduced version (simplified keyframes)
            pass
```

### WCAG 2.2 AA Compliance

#### Relevant Success Criteria

| Criteria | Description | Implementation |
|----------|-------------|----------------|
| 1.2.2 Captions (Prerecorded) | Captions provided for prerecorded audio | Caption system with toggle |
| 1.2.5 Audio Description | Audio description for video | N/A (not video-based) |
| 2.3.1 Three Flashes or Below | No content flashes > 3 times per second | No flashing content |
| 2.3.2 Three Flashes | Flashing content has warning | No flashing content |
| 2.3.3 Animation from Interactions | Users can reduce/turn off animations | Reduce motion setting |
| 1.4.1 Use of Color | Color not only visual cue | Multiple cues (color + icon + text) |
| 1.4.3 Contrast (Minimum) | Text has 4.5:1 contrast ratio | UI theme with sufficient contrast |
| 1.4.4 Resize Text | Text resizable up to 200% | Font scaling in settings |
| 2.4.6 Headings and Labels | Descriptive headings/labels | Proper UI labeling |
| 2.4.7 Focus Visible | Keyboard focus visible | Focus indicators |

---

## Caption & Subtitle Systems

### Subtitle Display System

```gdscript
# src/adapters/inbound/gameplay/subtitle_display.gd

class_name SubtitleDisplay
extends CanvasLayer

@export var subtitle_label: RichTextLabel
@export var show_duration: float = 3.0
@export var fade_duration: float = 0.5
@export var max_visible_lines: int = 3

var current_subtitles: Array[Dictionary] = []
var current_tween: Tween = null

func _ready() -> void:
    subtitle_label.visible = false
    subtitle_label.add_theme_font_override("font", get_font("font", "Font", 24))

func show_subtitle(text: String, duration: float = -1.0, speaker: String = "") -> void:
    if not GodotAccessibilityAdapter.should_show_captions():
        return
    
    # Cancel existing tween
    if current_tween:
        current_tween.kill()
    
    # Format subtitle
    var formatted_text := _format_subtitle(text, speaker)
    subtitle_label.text = formatted_text
    
    # Apply caption size
    var font_size := 24
    match GodotAccessibilityAdapter.get_caption_size():
        0: font_size = 18
        1: font_size = 24
        2: font_size = 32
    subtitle_label.add_theme_font_size_override("font_size", font_size)
    
    # Show with fade
    subtitle_label.visible = true
    subtitle_label.modulate.a = 0.0
    
    current_tween = create_tween()
    current_tween.tween_property(subtitle_label, "modulate:a", 1.0, fade_duration)
    
    # Auto-hide after duration
    var actual_duration := duration if duration > 0 else show_duration
    await get_tree().create_timer(actual_duration).timeout
    
    if current_tween:
        current_tween.kill()
    current_tween = create_tween()
    current_tween.tween_property(subtitle_label, "modulate:a", 0.0, fade_duration)
    await current_tween.finished
    subtitle_label.visible = false

func _format_subtitle(text: String, speaker: String) -> String:
    if speaker:
        return "[b]%s:[/b] %s" % [speaker, text]
    return text

func clear_subtitle() -> void:
    if current_tween:
        current_tween.kill()
    subtitle_label.visible = false
```

### Subtitle Queue System

```gdscript
# src/adapters/inbound/gameplay/subtitle_queue.gd

class_name SubtitleQueue
extends Node

signal subtitle_shown(text: String, speaker: String)
signal subtitle_hidden

var queue: Array[Dictionary] = []
var current_subtitle: Dictionary = null
var display_node: SubtitleDisplay = null

func _ready() -> void:
    display_node = get_node("SubtitleDisplay")

func enqueue(text: String, duration: float = 3.0, speaker: String = "", delay: float = 0.0) -> void:
    queue.append({
        "text": text,
        "duration": duration,
        "speaker": speaker,
        "delay": delay
    })
    
    if current_subtitle == null:
        _process_queue()

func _process_queue() -> void:
    if queue.is_empty():
        current_subtitle = null
        subtitle_hidden.emit()
        return
    
    current_subtitle = queue.pop_front()
    
    if current_subtitle["delay"] > 0:
        await get_tree().create_timer(current_subtitle["delay"]).timeout
    
    display_node.show_subtitle(
        current_subtitle["text"],
        current_subtitle["duration"],
        current_subtitle["speaker"]
    )
    
    subtitle_shown.emit(current_subtitle["text"], current_subtitle["speaker"])
    
    await get_tree().create_timer(current_subtitle["duration"]).timeout
    
    _process_queue()

func skip_current() -> void:
    if current_subtitle:
        display_node.clear_subtitle()
        _process_queue()

func clear() -> void:
    queue.clear()
    current_subtitle = null
    display_node.clear_subtitle()
```

### Audio-to-Subtitle Synchronization

```gdscript
# src/adapters/inbound/shared/audio/audio_bank.gd

class_name AudioBank
extends Node

# Preloaded audio clips with subtitle data
@export var audio_clips: Array[Dictionary] = []

# Current playing clips
var active_players: Array[AudioStreamPlayer] = []

func play_voice(clip_name: String, subtitle: String = "", speaker: String = "", bus: String = "Voice") -> AudioStreamPlayer:
    # Find clip
    var clip_data: Dictionary = null
    for data in audio_clips:
        if data.get("name") == clip_name:
            clip_data = data
            break
    
    if clip_data == null:
        printerr("Audio clip not found: %s" % clip_name)
        return null
    
    # Create player
    var player := AudioStreamPlayer.new()
    player.stream = clip_data["stream"]
    player.bus = bus
    add_child(player)
    active_players.append(player)
    
    # Connect signals
    player.finished.connect(_on_player_finished.bind(player))
    
    # Play
    player.play()
    
    # Show subtitle if available
    if subtitle:
        var subtitle_node := get_node("/root/World/SubtitleQueue")
        if subtitle_node:
            subtitle_node.enqueue(subtitle, player.stream.get_length(), speaker)
    
    return player

func _on_player_finished(player: AudioStreamPlayer) -> void:
    if active_players.has(player):
        active_players.erase(player)
        player.queue_free()
```

---

## Performance Optimization

### Audio Performance Best Practices

#### 1. **Object Pooling for Audio Players**

```gdscript
# audio_pool.gd

class_name AudioPool
extends Node

var pool: Array[AudioStreamPlayer] = []
var active_count: int = 0

func _ready() -> void:
    # Pre-warm pool
    for i in range(20):
        var player := AudioStreamPlayer.new()
        player.finish_mode = AudioStreamPlayer.FINISH_MODE_DISABLED
        add_child(player)
        pool.append(player)

func acquire_player() -> AudioStreamPlayer:
    if pool.is_empty():
        var player := AudioStreamPlayer.new()
        player.finish_mode = AudioStreamPlayer.FINISH_MODE_DISABLED
        add_child(player)
        active_count += 1
        return player
    
    return pool.pop_back()

func release_player(player: AudioStreamPlayer) -> void:
    player.stop()
    player.stream = null
    pool.append(player)
```

#### 2. **Distance-Based Audio Culling**

```gdscript
# audio_3d_manager.gd

class_name Audio3DManager
extends Node

@export var max_audible_distance: float = 50.0
@export var cull_check_interval: float = 0.5

func _ready() -> void:
    var timer := get_tree().create_timer(cull_check_interval, true)
    timer.timeout.connect(_on_cull_check)

func _on_cull_check() -> void:
    var player_pos := get_node("/root/World/Player").position
    
    for player in get_tree().get_nodes_in_group("audio_3d"):
        if player is AudioStreamPlayer3D:
            var distance := player.position.distance_to(player_pos)
            
            if distance > max_audible_distance:
                if player.playing:
                    player.stop()
            else:
                if not player.playing and player.stream:
                    player.play()
```

#### 3. **Bus Effect Optimization**

```gdscript
# audio_optimizer.gd

class_name AudioOptimizer
extends Node

# Disable effects on inactive buses
func optimize_bus_effects() -> void:
    for bus_idx in range(AudioServer.get_bus_count()):
        var bus_name := AudioServer.get_bus_name(bus_idx)
        var is_active := _is_bus_active(bus_name)
        
        for effect_idx in range(AudioServer.get_bus_effect_count(bus_idx)):
            AudioServer.set_bus_effect_enabled(bus_idx, effect_idx, is_active)

func _is_bus_active(bus_name: String) -> bool:
    # Check if any player is routed to this bus
    for player in get_tree().get_nodes_in_group("audio_player"):
        if player is AudioStreamPlayer and player.bus == bus_name:
            return true
    return false
```

---

## Code Samples & Implementation Patterns

### Complete Audio Manager Pattern

```gdscript
# src/adapters/inbound/shared/audio/audio_manager.gd

class_name AudioManager
extends Node

# Configuration
@export_group("Volume Settings")
@export var master_volume_db: float = 0.0
@export var music_volume_db: float = -6.0
@export var voice_volume_db: float = 0.0
@export var sfx_volume_db: float = 0.0
@export var ui_volume_db: float = 0.0

@export_group("Ducking Settings")
@export var voice_ducking_enabled: bool = true
@export var voice_duck_amount_db: float = -12.0
@export var voice_duck_fade: float = 0.3

@export_group("Accessibility")
@export var reduce_motion_affects_audio: bool = false

# State tracking
var voice_playing_count: int = 0
var active_players: Array[AudioStreamPlayer] = []

# Sub-nodes
var bus_setup: Node = null
var subtitle_queue: Node = null

func _ready() -> void:
    # Initialize buses
    bus_setup = $BusSetup
    if bus_setup:
        bus_setup.initialize()
    
    # Get subtitle queue
    subtitle_queue = $SubtitleQueue
    
    # Apply initial volumes
    apply_volume_settings()

func apply_volume_settings() -> void:
    _set_bus_volume("Master", master_volume_db)
    _set_bus_volume("Music", music_volume_db)
    _set_bus_volume("Voice", voice_volume_db)
    _set_bus_volume("SFX", sfx_volume_db)
    _set_bus_volume("UI", ui_volume_db)

func _set_bus_volume(bus_name: String, volume_db: float) -> void:
    var index := AudioServer.get_bus_index(bus_name)
    AudioServer.set_bus_volume_db(index, volume_db)

# Public API
func play_music(stream: AudioStream, fade_in: float = 1.0) -> AudioStreamPlayer:
    return _play_on_bus(stream, "Music", fade_in)

func play_voice(stream: AudioStream, subtitle: String = "", speaker: String = "", fade_in: float = 0.1) -> AudioStreamPlayer:
    var player := _play_on_bus(stream, "Voice", fade_in)
    
    if voice_ducking_enabled:
        voice_playing_count += 1
        if voice_playing_count == 1:
            _apply_voice_ducking()
    
    if subtitle_queue and subtitle:
        subtitle_queue.enqueue(subtitle, stream.get_length(), speaker)
    
    return player

func play_sfx(stream: AudioStream, position: Vector3 = null) -> AudioStreamPlayer:
    if position:
        var player_3d := AudioStreamPlayer3D.new()
        player_3d.stream = stream
        player_3d.position = position
        get_tree().root.add_child(player_3d)
        player_3d.play()
        active_players.append(player_3d)
        return player_3d
    else:
        return _play_on_bus(stream, "SFX")

func play_ui(stream: AudioStream) -> AudioStreamPlayer:
    return _play_on_bus(stream, "UI")

func _play_on_bus(stream: AudioStream, bus: String, fade_in: float = 0.0) -> AudioStreamPlayer:
    var player := AudioStreamPlayer.new()
    player.stream = stream
    player.bus = bus
    
    if fade_in > 0:
        player.volume_db = -80.0  # Start silent
        add_child(player)
        player.play()
        
        var tween := create_tween()
        tween.tween_property(player, "volume_db", 0.0, fade_in)
    else:
        add_child(player)
        player.play()
    
    active_players.append(player)
    player.finished.connect(_on_player_finished.bind(player, bus))
    
    return player

func _on_player_finished(player: AudioStreamPlayer, bus: String) -> void:
    if active_players.has(player):
        active_players.erase(player)
        player.queue_free()
    
    if bus == "Voice":
        voice_playing_count = max(0, voice_playing_count - 1)
        if voice_playing_count == 0:
            _remove_voice_ducking()

func _apply_voice_ducking() -> void:
    if not voice_ducking_enabled:
        return
    AudioUtils.fade_bus_volume("Music", music_volume_db + voice_duck_amount_db, voice_duck_fade)

func _remove_voice_ducking() -> void:
    AudioUtils.fade_bus_volume("Music", music_volume_db, voice_duck_fade)

func stop_all() -> void:
    for player in active_players:
        player.stop()
        player.queue_free()
    active_players.clear()
    voice_playing_count = 0
    
    if subtitle_queue:
        subtitle_queue.clear()

func pause_all() -> void:
    for player in active_players:
        if player.playing:
            player.stop()

func resume_all() -> void:
    for player in active_players:
        if not player.playing and player.stream:
            player.play()
```

### Accessibility Settings UI

```gdscript
# src/adapters/inbound/scenes/settings/accessibility_settings.gd

class_name AccessibilitySettings
extends Control

@onready var reduce_motion_check: CheckBox = $ReduceMotionCheck
@onready var captions_check: CheckBox = $CaptionsCheck
@onready var caption_size_box: OptionButton = $CaptionSizeBox

@onready var accessibility_port: AccessibilityPolicyPort = get_node("/root/AccessibilityPolicyPort")

func _ready() -> void:
    # Load current settings
    reduce_motion_check.button_pressed = accessibility_port.is_reduce_motion_enabled()
    captions_check.button_pressed = accessibility_port.are_captions_enabled()
    caption_size_box.selected = accessibility_port.get_caption_size()
    
    # Connect signals
    reduce_motion_check.toggled.connect(_on_reduce_motion_toggled)
    captions_check.toggled.connect(_on_captions_toggled)
    caption_size_box.item_selected.connect(_on_caption_size_changed)

func _on_reduce_motion_toggled(pressed: bool) -> void:
    accessibility_port.set_reduce_motion_enabled(pressed)

func _on_captions_toggled(pressed: bool) -> void:
    accessibility_port.set_captions_enabled(pressed)

func _on_caption_size_changed(index: int) -> void:
    accessibility_port.set_caption_size(index)
```

---

## Asset Sources & Licensing

### Recommended Audio Asset Sources

#### 1. **Kenney Audio Packs** (CC0 - No Attribution Required)

| Pack Name | URL | Format | Notes |
|-----------|-----|--------|-------|
| Kenney UI Audio | [Asset Library](https://godotengine.org/asset-library/asset/795) | WAV | 50 UI SFX, Godot-ready |
| Kenney Interface Sounds | [Asset Library](https://godotengine.org/asset-library/asset/793) | WAV | 100 interface sounds |
| All Kenney Audio | [kenney.nl/audio](https://kenney.nl/assets/category:Audio) | WAV/OGG | 20+ packs available |

**Kenney Usage in Godot:**
- Download from Asset Library via Editor
- Or download from GitHub: [Calinou/kenney-ui-audio](https://github.com/Calinou/kenney-ui-audio)
- All Kenney assets are CC0 (Public Domain)

#### 2. **Freesound** (CC0 Filtered)

- **Website**: [freesound.org](https://freesound.org)
- **Search Filter**: License = CC0
- **Recommended Tags**: ui, click, button, whoosh, impact, footstep, ambient, nature
- **Format**: WAV, OGG

**Top CC0 Contributors on Freesound:**
- inspectorj
- acclivity
- cydon
- juskiddink
- tjandjohn

#### 3. **OpenGameArt** (CC0/CC-BY)

- **Website**: [opengameart.org](https://opengameart.org)
- **Category**: [CC0 Sound Effects](https://opengameart.org/content/cc0-sound-effects)
- **Filter**: License = CC0

#### 4. **Poly Pizza** (CC0)

- **Website**: [poly-pizza.com](https://poly-pizza.com)
- **Audio Section**: Free SFX packs
- **License**: All CC0

#### 5. **GamesFXMaker** (Commercial License Filter)

- **Website**: [gamesfxmaker.com](https://gamesfxmaker.com)
- **Feature**: Filter by CC0 & Commercial Use
- **Format**: WAV, OGG

#### 6. **BBC Sound Effects** (Public Domain)

- **Website**: [BBC Sound Effects](https://sound-effects.bbcrewind.co.uk)
- **License**: Public Domain (16,000+ sounds)
- **Categories**: Nature, Transport, Industry, Domestic, etc.

#### 7. **Zapsplat** (Free License)

- **Website**: [zapsplat.com](https://www.zapsplat.com)
- **License**: Free with attribution (check individual licenses)
- **Categories**: Game SFX, Foley, Ambience

### Asset Organization Strategy

```
res://assets/audio/
├── music/
│   ├── ambient/
│   │   ├── forest_ambient.ogg
│   │   └── beach_ambient.ogg
│   ├── combat/
│   │   ├── battle_theme_01.ogg
│   │   └── boss_theme_01.ogg
│   └── menu/
│       └── main_menu_theme.ogg
├── voice/
│   ├── ziemek/
│   │   ├── greeting_01.wav
│   │   └── instruction_01.wav
│   ├── gniewko/
│   │   └── response_01.wav
│   └── narrator/
│       └── intro_01.wav
├── sfx/
│   ├── ui/
│   │   ├── button_click.wav
│   │   ├── button_hover.wav
│   │   └── inventory_open.wav
│   ├── combat/
│   │   ├── sword_swing.wav
│   │   ├── sword_hit.wav
│   │   └── enemy_hurt.wav
│   ├── environment/
│   │   ├── footstep_grass.wav
│   │   ├── footstep_sand.wav
│   │   └── water_splash.wav
│   └── items/
│       ├── pickaxe_swing.wav
│       ├── wood_chop.wav
│       └── stone_mine.wav
└── raw/
    └── (source files for editing)
```

### Recommended Audio Specifications

| Type | Format | Sample Rate | Bit Depth | Channels | Notes |
|------|--------|-------------|-----------|----------|-------|
| UI SFX | WAV | 44.1 kHz | 16-bit | Mono | Short, transient sounds |
| Combat SFX | WAV | 44.1 kHz | 16-bit | Stereo | Directional sounds |
| Music | OGG | 44.1 kHz | 16-bit | Stereo | Long, looping tracks |
| Voice | OGG | 44.1 kHz | 16-bit | Mono | Dialogue lines |
| Ambient | OGG | 44.1 kHz | 16-bit | Stereo | Looping background |

---

## Best Practices & Standards Compliance

### Audio Best Practices

#### 1. **Volume Standards**

| Category | Recommended Peak | Reason |
|----------|------------------|--------|
| Music | -12 dB to -6 dB | Background, shouldn't overpower |
| Voice | -6 dB to -3 dB | Must be clear and intelligible |
| SFX | -6 dB to 0 dB | Important feedback, varies by effect |
| UI | -12 dB to -6 dB | Subtle, non-intrusive |

#### 2. **Mixing Guidelines**

- **Voice Priority**: Always ensure voice is audible over music and SFX
- **Ducking**: Music should duck 6-12 dB when voice plays
- **Frequency Balance**: 
  - Music: 100-8000 Hz (full range)
  - Voice: 100-4000 Hz (human voice range)
  - SFX: Varies by effect
- **Headroom**: Always leave 6 dB of headroom on the master bus

#### 3. **Dynamic Range**

- Target DR (Dynamic Range): 8-12 dB for music
- Use compression to control dynamics
- Limit final output to prevent clipping

#### 4. **Spatial Audio**

- Use `AudioStreamPlayer3D` for positional audio
- Set proper `max_distance` and `attenuation` models
- Consider using HRTF for more realistic spatial audio

### Accessibility Best Practices

#### 1. **Reduce Motion**

- **What to Reduce**:
  - Screen shake effects
  - Camera movements (except essential)
  - Particle effects
  - UI animations
  - Background parallax
  
- **What to Keep**:
  - Essential gameplay feedback (hit flashes, damage indicators)
  - Important UI state changes
  - Loading indicators

#### 2. **Captions/Subtitles**

- **Timing**: Synchronized within 200ms of audio
- **Position**: Bottom-center, with speaker identification
- **Styling**: 
  - Background: Semi-transparent black
  - Text: White with black outline
  - Font: Readable, minimum 18pt
- **Options**:
  - Toggle on/off
  - Size: Small/Medium/Large
  - Color: Customizable

#### 3. **Color Contrast**

- **Minimum Ratio**: 4.5:1 for normal text (WCAG AA)
- **Large Text**: 3:1 ratio acceptable
- **UI Elements**: Clear visual distinction between states

#### 4. **Keyboard Navigation**

- All UI elements accessible via keyboard
- Clear focus indicators
- Logical tab order
- Escape to close/cancel

### Code Quality Best Practices

#### 1. **Audio Node Management**

```gdscript
# DO: Use object pooling for audio players
var audio_pool: AudioPool = get_node("/root/AudioPool")
var player := audio_pool.acquire_player()

# DON'T: Create players on the fly without cleanup
var player := AudioStreamPlayer.new()  # May leak if not managed
```

#### 2. **Bus Organization**

```gdscript
# DO: Use semantic bus names
player.bus = "Voice"  # Clear intent

# DON'T: Use generic or hardcoded indices
player.bus = "Bus 2"  # What is this?
```

#### 3. **Accessibility Checks**

```gdscript
# DO: Centralize accessibility checks
if AudioManager.should_reduce_motion():
    return

# DON'T: Hardcode checks in multiple places
if ProjectSettings.get("accessibility/reduce_motion"):
    return
```

---

## Testing & Validation Checklist

### Audio Testing Checklist

- [ ] **Bus Configuration**
  - [ ] All buses (Music, Voice, SFX, UI, Ambient) exist and are configured
  - [ ] Bus volumes are set to appropriate levels
  - [ ] Effects are applied to correct buses
  
- [ ] **Ducking System**
  - [ ] Music ducks when voice plays
  - [ ] Ducking amount is appropriate (6-12 dB)
  - [ ] Ducking attack/release times are smooth
  - [ ] Multiple voice lines don't cause excessive ducking
  
- [ ] **Volume Balance**
  - [ ] Voice is clear and intelligible over music
  - [ ] Music volume doesn't overpower SFX
  - [ ] UI sounds are subtle but audible
  - [ ] No clipping on any bus
  
- [ ] **Spatial Audio**
  - [ ] 3D audio sources are positional
  - [ ] Volume falls off with distance
  - [ ] Panning works correctly (left/right)
  
- [ ] **Performance**
  - [ ] No audio stuttering or dropouts
  - [ ] CPU usage < 5% for audio processing
  - [ ] Memory usage stable with many audio sources

### Accessibility Testing Checklist

- [ ] **Reduce Motion**
  - [ ] Setting persists between sessions
  - [ ] Screen shake is disabled
  - [ ] Particle effects are hidden
  - [ ] UI animations are simplified
  - [ ] Essential feedback (hit indicators) still visible
  
- [ ] **Captions**
  - [ ] Captions toggle works
  - [ ] Captions appear synchronized with audio
  - [ ] Speaker identification is shown
  - [ ] Caption size options work
  - [ ] Captions are readable on all backgrounds
  
- [ ] **Visual Accessibility**
  - [ ] Text has sufficient contrast (4.5:1 minimum)
  - [ ] UI elements have clear focus states
  - [ ] Color is not the only visual cue
  - [ ] Text is resizable
  
- [ ] **Keyboard Navigation**
  - [ ] All UI elements accessible via keyboard
  - [ ] Tab order is logical
  - [ ] Focus indicators are visible
  - [ ] All actions have keyboard shortcuts or are reachable

### Performance Testing Checklist

- [ ] **Tier 1 Hardware** (High-end)
  - [ ] Frame rate > 60 FPS with audio enabled
  - [ ] Audio latency < 20ms
  - [ ] No audio buffer underruns
  
- [ ] **Tier 2 Hardware** (Laptop/Integrated)
  - [ ] Frame rate > 30 FPS with audio enabled
  - [ ] Audio latency < 50ms
  - [ ] No audio buffer underruns
  
- [ ] **Stress Testing**
  - [ ] 50+ simultaneous audio sources
  - [ ] All buses active simultaneously
  - [ ] Rapid play/stop of audio clips
  
- [ ] **Memory Testing**
  - [ ] Memory usage doesn't grow over time
  - [ ] No audio-related memory leaks
  - [ ] Proper cleanup of audio nodes

### Manual QA Evidence Required

Based on PLAN.md acceptance criteria:

1. **Screenshot Evidence**
   - [ ] Launcher screen (clean, no debug text)
   - [ ] Spawn point (first-person view)
   - [ ] Guide interaction moment
   - [ ] Region transition
   - [ ] Combat moment
   
2. **Performance Measurements**
   - [ ] Tier 1 FPS (min/avg/max)
   - [ ] Tier 2 FPS (min/avg/max)
   - [ ] Audio CPU usage (%)
   - [ ] Memory usage (MB)
   - [ ] Load times (seconds)
   
3. **Accessibility Validation**
   - [ ] Reduce motion enabled/disabled comparison
   - [ ] Captions enabled/disabled comparison
   - [ ] Color contrast measurements
   - [ ] Keyboard navigation flow
   
4. **Audio Validation**
   - [ ] Bus configuration screenshot
   - [ ] Volume level measurements
   - [ ] Ducking effectiveness test
   - [ ] No clipping verification

---

## Learning Resources

### Official Godot Documentation

| Topic | URL |
|-------|-----|
| Audio Buses Tutorial | [https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html) |
| Audio Effects | [https://docs.godotengine.org/en/4.6/tutorials/audio/audio_effects.html](https://docs.godotengine.org/en/4.6/tutorials/audio/audio_effects.html) |
| AudioStreamPlayer | [https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html) |
| AudioStreamPlayer3D | [https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html) |
| AudioServer | [https://docs.godotengine.org/en/stable/classes/class_audioserver.html](https://docs.godotengine.org/en/stable/classes/class_audioserver.html) |
| Accessibility Properties | [https://docs.godotengine.org/en/stable/classes/class_control.html#accessibility](https://docs.godotengine.org/en/stable/classes/class_control.html#accessibility) |

### Audio Production & Mixing

| Resource | URL |
|----------|-----|
| Godot Audio Management Basics | [https://uhiyama-lab.com/en/notes/godot/godot-audio-management-basics-audiostreamplayer-audiobus/](https://uhiyama-lab.com/en/notes/godot/godot-audio-management-basics-audiostreamplayer-audiobus/) |
| Godot Audio System Guide | [https://gamineai.com/courses/build-complete-game-godot-4/lessons/lesson-9-audio-system-sound-design](https://gamineai.com/courses/build-complete-game-godot-4/lessons/lesson-9-audio-system-sound-design) |
| Reddit: Sound Design in Godot | [https://www.reddit.com/r/godot/comments/1kv6rxd/sound_design_in_godot_44_how_to_do_it_right/](https://www.reddit.com/r/godot/comments/1kv6rxd/sound_design_in_godot_44_how_to_do_it_right/) |
| Master Sound Effects in Godot | [https://sfxengine.com/blog/sound-effects-in-godot](https://sfxengine.com/blog/sound-effects-in-godot) |
| Easy-to-Use Audio for Every Situation | [https://www.reddit.com/r/godot/comments/184wah4/easytouse_audio_for_basically_every_situation_in/](https://www.reddit.com/r/godot/comments/184wah4/easytouse_audio_for_basically_every_situation_in/) |

### Accessibility Resources

| Resource | URL |
|----------|-----|
| WCAG 2.2 Guidelines | [https://www.w3.org/TR/WCAG22/](https://www.w3.org/TR/WCAG22/) |
| WCAG Quick Reference | [https://www.w3.org/WAI/WCAG22/quickref/](https://www.w3.org/WAI/WCAG22/quickref/) |
| Game Accessibility Guidelines | [https://game-accessibility.com/](https://game-accessibility.com/) |
| Accessibility in Godot 4.5 | [https://godotengine.org/releases/4.5/](https://godotengine.org/releases/4.5/) |
| AccessKit in Godot | [https://caniplaythat.com/2025/04/29/godot-4-5-improves-accessibility-support-including-screen-readers/](https://caniplaythat.com/2025/04/29/godot-4-5-improves-accessibility-support-including-screen-readers/) |
| Filament Games Accessibility Glossary | [https://www.filamentgames.com/blog/accessibility-terms-for-game-developers-a-wcag-2-1-aa-glossary](https://www.filamentgames.com/blog/accessibility-terms-for-game-developers-a-wcag-2-1-aa-glossary) |

### Audio Asset Sources

| Source | URL | License |
|--------|-----|---------|
| Kenney Audio | [https://kenney.nl/assets/category:Audio](https://kenney.nl/assets/category:Audio) | CC0 |
| Kenney UI Audio (Godot Asset Library) | [https://godotengine.org/asset-library/asset/795](https://godotengine.org/asset-library/asset/795) | CC0 |
| Freesound | [https://freesound.org](https://freesound.org) | CC0 (filtered) |
| OpenGameArt | [https://opengameart.org](https://opengameart.org) | CC0/CC-BY |
| Poly Pizza | [https://poly-pizza.com](https://poly-pizza.com) | CC0 |
| BBC Sound Effects | [https://sound-effects.bbcrewind.co.uk](https://sound-effects.bbcrewind.co.uk) | Public Domain |
| Zapsplat | [https://www.zapsplat.com](https://www.zapsplat.com) | Free/Attribution |
| GamesFXMaker | [https://gamesfxmaker.com](https://gamesfxmaker.com) | CC0 Filter |

### Community & Support

| Resource | URL |
|----------|-----|
| Godot Forum - Audio | [https://forum.godotengine.org/c/audio](https://forum.godotengine.org/c/audio) |
| Godot Discord | [https://discord.gg/4JBkykG](https://discord.gg/4JBkykG) |
| Godot Subreddit | [https://www.reddit.com/r/godot/](https://www.reddit.com/r/godot/) |

---

## Summary & Recommendations

### Key Findings

1. **Godot 4.6 Audio System** is robust and production-ready with proper bus architecture
2. **AudioEffectCompressor** provides excellent dynamic control with sidechain support
3. **AccessKit Integration** in Godot 4.5+ provides screen reader support but not system-level reduce motion
4. **WCAG 2.2 AA** requirements are achievable with proper implementation
5. **Kenney Audio Packs** offer the best CC0-licensed, Godot-ready audio assets

### Implementation Priority

1. **High Priority** (Gate A blockers):
   - Complete bus architecture with proper mixing
   - Voice ducking system (sidechain compression)
   - Reduce motion implementation
   - Caption system with timing
   
2. **Medium Priority**:
   - Audio optimization (pooling, culling)
   - Performance validation on Tier 1/Tier 2
   - Accessibility settings UI
   
3. **Low Priority**:
   - Advanced audio effects (reverb, EQ)
   - HRTF spatial audio
   - Platform-specific reduce motion detection

### Estimated Effort

| Task | Complexity | Estimated Hours | Dependencies |
|------|------------|-----------------|--------------|
| Bus Architecture Setup | Medium | 4-6 | None |
| Ducking System | Medium | 4-6 | Bus Architecture |
| Reduce Motion System | Low | 2-4 | Accessibility Port |
| Caption System | Medium | 6-8 | Audio Bank |
| Performance Optimization | Medium | 4-6 | All audio systems |
| QA & Testing | High | 8-12 | All systems |
| **Total** | | **28-48 hours** | |

### Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Audio latency on Tier 2 | Medium | High | Test early, optimize buffer sizes |
| Bus configuration issues | Low | Medium | Use version control, validate often |
| Accessibility compliance gaps | Medium | Medium | Follow WCAG checklist, test with screen readers |
| Performance bottlenecks | Low | High | Profile early, use object pooling |

---

## Next Steps

1. **Implement Bus Architecture**: Use the provided `bus_setup.gd` code
2. **Configure Ducking**: Implement sidechain compression for Voice→Music
3. **Complete Accessibility Port**: Finalize `accessibility_policy_port.gd`
4. **Build Subtitle System**: Implement `subtitle_display.gd` and `subtitle_queue.gd`
5. **Create QA Evidence**: Run tests on Tier 1 and Tier 2 hardware
6. **Write Manual QA Report**: Document findings in `manual-qa/VS-006/REPORT.md`

---

*Document Version: 1.0*  
*Generated: 2026-07-18*  
*Status: Ready for Implementation Review*
