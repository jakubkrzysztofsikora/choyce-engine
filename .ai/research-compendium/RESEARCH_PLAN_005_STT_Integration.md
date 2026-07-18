# RESEARCH_PLAN_005: Speech-to-Text (STT) Integration for Local-First Voice Input

**Source**: PLAN.md Gate 5 - "Replace canned STT with local-first real input and explicit opt-in fallback"
**Title**: Local-First Speech-to-Text Implementation with Privacy-Focused Design
**Specialty**: ai-integration, speech-processing, privacy-engineering
**Status**: todo
**Owner**: codex
**Complexity**: HIGH

---

## Table of Contents
1. [Task Overview](#task-overview)
2. [Current Implementation Analysis](#current-implementation-analysis)
3. [Online Research Summary](#online-research-summary)
4. [Technical Deep Dive](#technical-deep-dive)
5. [Code Samples](#code-samples)
6. [Asset Packages and Tools](#asset-packages-and-tools)
7. [Learning Resources](#learning-resources)
8. [Implementation Checklist](#implementation-checklist)
9. [Child-Safety Constraints](#child-safety-constraints)
10. [References](#references)

---

## Task Overview

### Objective
Replace the current canned/placeholder **Speech-to-Text (STT)** system with a **local-first**, privacy-preserving real STT implementation that works offline and provides explicit opt-in fallback to cloud-based solutions when local processing is unavailable or insufficient.

### Acceptance Criteria (from PLAN.md Gate 5)
1. **Local-First**: Primary STT processing happens on-device without internet
2. **Real Input**: Replace canned/placeholder voice with actual microphone input
3. **Explicit Opt-In**: Cloud fallback requires explicit user/parent consent
4. **Privacy-Preserving**: No audio leaves the device without explicit permission
5. **Offline Capable**: Works without internet connection
6. **Fallback Mechanism**: Graceful degradation to canned input when STT unavailable
7. **Age-Appropriate**: Child-friendly voice recognition with safe language filtering

### Key Requirements
- **COPPA Compliant**: No data collection without verifiable parental consent
- **Deterministic**: Same audio input produces same text output (for testing)
- **Reversible**: All STT results can be undone/edited
- **Audit Log**: All STT operations are logged for safety review
- **Performance**: Local processing must work on Tier 2 hardware
- **Latency**: < 500ms for local processing, < 2s for cloud fallback

---

## Current Implementation Analysis

### Existing Infrastructure
From the codebase:
- `src/adapters/outbound/elevenlabs_voice_prompt_adapter.gd` - Current voice adapter
- `src/ports/outbound/voice_prompt_port.gd` - Voice prompt interface
- `shell/` - Tauri shell integration
- VS-009: Governed AI Flows (RESEARCH_VS-009_Governed_AI_Flows.md)
- VS-007: Tauri Sidecar (RESEARCH_VS-007_Tauri_Sidecar_Part1-3.md)
- `.ai/tasks/backlog.yaml` - Task definitions

### Current State Assessment
```
Current Implementation:
├── Canned/Placeholder Voice
│   ├── Pre-recorded audio clips
│   ├── Static text responses
│   └── No real microphone input
├── ElevenLabs Integration
│   ├── Cloud-based TTS (Text-to-Speech)
│   ├── No STT (Speech-to-Text) currently
│   └── Requires internet connection
└── Tauri Bridge
    ├── WebSocket IPC
    ├── Command execution
    └── No audio streaming yet

Required Implementation:
├── Local STT Engine
│   ├── On-device speech recognition
│   ├── Offline-capable
│   └── Privacy-preserving
├── Microphone Access
│   ├── Audio capture
│   ├── Permission handling
│   └── Audio preprocessing
├── Cloud Fallback
│   ├── Opt-in only
│   ├── Explicit consent
│   └── Privacy controls
└── Safety Layer
    ├── Content filtering
    ├── Parent approval
    └── Audit logging
```

### Architecture Context
```
┌─────────────────────────────────────────────────────────┐
│                   Godot Engine                            │
│  ┌─────────────────────────────────────────────────────┐│
│  │                Audio System                           ││
│  │  ┌─────────────┐  ┌─────────────┐                    ││
│  │  │ Microphone   │  │ STT Processor │                    ││
│  │  │   Input      │──▶│ (Local/Cloud)│                    ││
│  │  └─────────────┘  └────────┬────────┘                    ││
│  │                             │                            ││
│  └─────────────────────────────────────┼────────────────┘│
│                                          │                  │
│┌─────────────────────────────────────────▼──────────────┐│
││               Tauri Shell (Rust)                         ││
││  ┌─────────────────────────────────────────────────────┐││
││  │              Audio Service                          │││
││  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │││
││  │  │ Audio Capture │  │ Local STT    │  │ Cloud STT   │  │││
││  │  │   (Rust)     │──▶│   (Rust)     │──▶│   (Rust)     │  │││
││  │  └─────────────┘  └─────────────┘  └─────────────┘  │││
││  └─────────────────────────────────────────────────────┘││
│└─────────────────────────────────────────────────────────┘│
└───────────────────────────────────────────────────────────┘
```

### Key Components to Implement

| Component | Responsibility | Location |
|-----------|---------------|----------|
| STTService | Main STT interface | `src/adapters/outbound/` |
| LocalSTT | On-device STT processing | `src/adapters/outbound/` (Rust) |
| CloudSTT | Cloud STT with opt-in | `src/adapters/outbound/` (Rust) |
| AudioCapture | Microphone access | `shell/` (Rust) |
| VoicePermission | Permission management | `src/domain/safety/` |
| STTSafety | Content filtering | `src/domain/safety/` |
| STTAudit | Operation logging | `src/domain/audit/` |

---

## Online Research Summary

### 1. Local STT Engines

**Overview of Local STT Options**:

| Engine | Language | Model Size | Offline | Accuracy | License | Platform |
|--------|----------|------------|---------|----------|---------|----------|
| **Vosk** | Multi | 50-500MB | ✅ Yes | ⭐⭐⭐ | Apache 2.0 | Win/macOS/Linux |
| **Whisper.cpp** | Multi | 50-1500MB | ✅ Yes | ⭐⭐⭐⭐ | MIT | Win/macOS/Linux |
| **TensorFlow Lite STT** | Multi | 10-100MB | ✅ Yes | ⭐⭐⭐ | Apache 2.0 | All |
| **Coqui STT** | Multi | 50-500MB | ✅ Yes | ⭐⭐⭐⭐ | MIT | Win/macOS/Linux |
| **PicoVoice** | English | 5-20MB | ✅ Yes | ⭐⭐ | Apache 2.0 | All |
| **Mozilla DeepSpeech** | English | 100-500MB | ✅ Yes | ⭐⭐⭐ | MPL 2.0 | Win/macOS/Linux |
| **Riva** | Multi | 1-5GB | ⚠️ Partial | ⭐⭐⭐⭐⭐ | Apache 2.0 | Win/Linux |

**Recommended for Choyce Engine**: **Whisper.cpp**

#### Whisper.cpp (Best Choice)
- **Repository**: [github.com/ggerganov/whisper.cpp](https://github.com/ggerganov/whisper.cpp)
- **Model Size**: 38MB (tiny) to 1.5GB (large)
- **Languages**: 99+ languages
- **Performance**: Real-time on modern CPUs
- **Accuracy**: Comparable to cloud services
- **License**: MIT (commercial-friendly)
- ** Bindings**: C/C++ API, Python, Rust (via FFI)

**Whisper.cpp Models**:
| Model | Size | RAM | VRAM | Speed | Accuracy |
|-------|------|-----|------|-------|----------|
| tiny | 38MB | 1GB | N/A | 2-5x | ⭐⭐⭐ |
| tiny.en | 22MB | 512MB | N/A | 3-7x | ⭐⭐⭐ (English only) |
| base | 140MB | 2GB | N/A | 1-2x | ⭐⭐⭐⭐ |
| base.en | 75MB | 1GB | N/A | 2-3x | ⭐⭐⭐⭐ (English only) |
| small | 470MB | 4GB | N/A | 0.8-1.2x | ⭐⭐⭐⭐ |
| small.en | 240MB | 2GB | N/A | 1-1.5x | ⭐⭐⭐⭐⭐ (English only) |
| medium | 1.5GB | 8GB | N/A | 0.5-0.8x | ⭐⭐⭐⭐⭐ |
| large | 3.0GB | 16GB | N/A | 0.3-0.5x | ⭐⭐⭐⭐⭐ |

**For Tier 2 Hardware**: **tiny.en** or **base.en** (English only, 22-75MB)

**Features**:
- Pure C++ with no dependencies
- Runs on CPU (no GPU required)
- Supports AVX, AVX2, AVX-512 for acceleration
- Streaming mode for real-time transcription
- Temperature and repetition penalty control
- Word-level timestamps

#### Vosk (Alternative)
- **Repository**: [alphacephei.com/vosk](https://alphacephei.com/vosk/)
- **Model Size**: 50-500MB
- **Languages**: 20+ languages
- **Performance**: Real-time on modern CPUs
- **License**: Apache 2.0
- **Bindings**: Python, Java, C#, Rust

**Vosk Features**:
- Kaldi-based speech recognition
- Streaming API
- Speaker diarization
- Custom vocabulary support
- Works offline

**Vosk Models**:
| Model | Size | Languages | Notes |
|-------|------|-----------|-------|
| vosk-model-small-en-us-0.15 | 45MB | English US | Best for children |
| vosk-model-en-us-0.22 | 130MB | English US | Higher accuracy |
| vosk-model-en-us-0.22-lg | 330MB | English US | Large model |
| vosk-model-small-en-in-0.15 | 45MB | English IN | Indian accent |

#### Coqui STT (STT-rs)
- **Repository**: [github.com/coqui-ai/STT](https://github.com/coqui-ai/STT)
- **Rust Binding**: [stt-rs](https://github.com/mozilla/stt-rs)
- **Model Size**: 50-500MB
- **Languages**: 10+ languages
- **Performance**: Good on CPU
- **License**: MIT/Apache 2.0

### 2. Cloud STT Services (Opt-In Only)

**Cloud STT Options for Fallback**:

| Service | Accuracy | Latency | Languages | Free Tier | COPPA |
|---------|----------|---------|-----------|-----------|-------|
| **Whisper API** | ⭐⭐⭐⭐⭐ | ~5s | 99+ | Limited | ✅ Yes |
| **Google Cloud STT** | ⭐⭐⭐⭐⭐ | <1s | 120+ | $300 | ✅ Yes |
| **AWS Transcribe** | ⭐⭐⭐⭐ | ~2s | 100+ | 60min/mo | ✅ Yes |
| **Azure STT** | ⭐⭐⭐⭐⭐ | <1s | 100+ | 5hr/mo | ✅ Yes |
| **IBM Watson** | ⭐⭐⭐⭐ | ~2s | 100+ | 100min/mo | ✅ Yes |
| **Deepgram** | ⭐⭐⭐⭐⭐ | <1s | 50+ | 1hr/mo | ✅ Yes |
| **AssemblyAI** | ⭐⭐⭐⭐ | ~3s | 10+ | 1hr/mo | ✅ Yes |
| **Mozilla DeepSpeech API** | ⭐⭐⭐ | ~2s | 10+ | Limited | ⚠️ Partial |

**Recommended for Choyce Engine**: **Whisper API** (OpenAI) or **Azure STT**

#### Whisper API (OpenAI)
- **Endpoint**: `https://api.openai.com/v1/audio/transcriptions`
- **Pricing**: $0.006/minute
- **Features**:
  - Multiple languages
  - Word-level timestamps
  - Temperature control
  - Response format options

**Request Example**:
```json
{
  "model": "whisper-1",
  "file": "audio.mp3",
  "language": "en",
  "temperature": 0.2,
  "response_format": "verbose_json"
}
```

#### Azure STT
- **Endpoint**: `https://{region}.tts.speech.microsoft.com/speechtotext/v3.0`
- **Pricing**: Free tier: 5 hours/month
- **Features**:
  - Real-time streaming
  - Multiple languages
  - Speaker diarization
  - Custom models
  - COPPA compliant

### 3. Microphone Access and Audio Processing

**Web Audio API (Browser)**:
```javascript
// Get microphone access
navigator.mediaDevices.getUserMedia({ audio: true })
  .then(stream => {
    // Create audio context
    const audioContext = new AudioContext();
    const source = audioContext.createMediaStreamSource(stream);
    const processor = audioContext.createScriptProcessor(4096, 1, 1);
    
    source.connect(processor);
    processor.connect(audioContext.destination);
    
    processor.onaudioprocess = (e) => {
      const audioData = e.inputBuffer.getChannelData(0);
      // Send to STT engine
    };
  })
  .catch(err => {
    console.error('Microphone access denied:', err);
  });
```

**Tauri Audio Capture (Rust)**:
```rust
// Using tauri-plugin-audio or cpal
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};

fn setup_microphone() -> Result<(), anyhow::Error> {
    let host = cpal::default_host();
    let device = host.default_input_device()?;
    let config = device.default_input_config()?;
    
    let stream = device.build_input_stream(
        &config.into(),
        move |data: &[f32], _: &_| {
            // Process audio data
            process_audio(data);
        },
        |err| eprintln!("Audio stream error: {:?}", err),
    )?;
    
    stream.play()?;
    Ok(())
}
```

**Audio Preprocessing**:
1. **Noise Suppression**: Remove background noise
2. **Normalization**: Normalize audio levels
3. **Sample Rate Conversion**: Convert to 16kHz (standard for STT)
4. **Channel Selection**: Mono conversion
5. **Silence Detection**: Skip silent segments
6. **Voice Activity Detection (VAD)**: Detect when speech starts/stops

**VAD Libraries**:
- [webrtc-vad](https://github.com/rust-av/webrtc-vad) - WebRTC Voice Activity Detector
- [silero-vad](https://github.com/snakers4/silero-vad) - PyTorch-based VAD
- [soniox](https://github.com/soniox/soniox) - Fast VAD

### 4. Privacy and COPPA Compliance

**COPPA Requirements for STT**:
1. **No Collection**: No audio data collected without parental consent
2. **Verifiable Consent**: Parent must explicitly approve
3. **Data Deletion**: Parents can delete child's data
4. **Review Rights**: Parents can review data collected
5. **Limited Use**: Data used only for STT, not for profiling

**Privacy-Preserving Design**:
1. **Local-Only Default**: All processing happens on-device
2. **Explicit Opt-In**: Cloud processing requires explicit consent
3. **Data Minimization**: Only process audio, don't store it
4. **Transparency**: Clear indication when microphone is active
5. **Control**: Easy to disable/enable

**Implementation Checklist for COPPA**:
- [ ] Audio never leaves device without consent
- [ ] Consent flow requires parent verification
- [ ] Consent is stored and auditable
- [ ] Audio is not stored after processing
- [ ] Audio is deleted when app is closed
- [ ] No user identifiers in audio or requests

### 5. Rust + STT Integration

**Rust Crates for STT**:

| Crate | Description | Stars | Last Updated |
|-------|-------------|-------|--------------|
| **whisper-rs** | Whisper.cpp Rust bindings | [whisper-rs](https://github.com/tazz4843/whisper-rs) | 1.5k | 2024 |
| **tch-rs** | PyTorch Rust bindings | [tch-rs](https://github.com/LaurentMazare/tch-rs) | 3.5k | 2024 |
| **stt-rs** | Coqui STT Rust bindings | [stt-rs](https://github.com/mozilla/stt-rs) | 200 | 2023 |
| **vosk-rs** | Vosk Rust bindings | [vosk-rs](https://github.com/alphacep/vosk-rs) | 50 | 2023 |
| **cpal** | Cross-platform audio I/O | [cpal](https://github.com/RustAudio/cpal) | 2.5k | 2024 |
| **rubato** | Audio resampling | [rubato](https://github.com/mvdnes/rubato.rs) | 400 | 2024 |
| **hound** | WAV/MP3 decoding | [hound](https://github.com/ruuda/hound) | 500 | 2023 |

**Recommended Stack**:
```
┌─────────────────────────────┐
│         Godot Side           │
│  ┌─────────────────────────┐│
│  │  Audio Capture Node       ││
│  │  (Streams to Tauri)       ││
│  └────────┬────────────────┘│
│           │                  │
│  ┌────────▼────────────────┐│
│  │      Tauri Bridge         ││
│  │  (WebSocket IPC)          ││
│  └────────┬────────────────┘│
└───────────┼──────────────────┘
            │
┌───────────▼──────────────────┐
│       Rust Side (Shell)        │
│  ┌───────────────────────────┐│
│  │      Audio Service         ││
│  │  ┌─────────┐  ┌─────────┐ ││
│  │  │ cpal    │  │ whisper │ ││
│  │  │ (Audio  │──▶│ -rs    │ ││
│  │  │  Input) │  │         │ ││
│  │  └─────────┘  └─────────┘ ││
│  │       │                │    ││
│  │       ▼                ▼    ││
│  │  ┌─────────┐  ┌─────────┐ ││
│  │  │ rubato  │  │ tch-rs  │ ││
│  │  │(Resample│  │ (PyTorch)│ ││
│  │  │ )       │  │         │ ││
│  │  └─────────┘  └─────────┘ ││
│  └───────────────────────────┘│
└────────────────────────────────┘
```

**Example whisper-rs Usage**:
```rust
use whisper_rs::{WhisperContext, WhisperState, FullParams};

fn run_stt(audio: &[f32], sample_rate: u32) -> String {
    // Load model
    let ctx = WhisperContext::new("models/ggml-tiny.en.bin").unwrap();
    let state = ctx.create_state().unwrap();
    
    // Set parameters
    let params = FullParams::new(
        whisper_rs::SamplingStrategy::Greedy { best_of: 1 },
    ).with_print_special(false)
     .with_print_progress(false)
     .with_print_realtime(false)
     .with_print_timestamps(false);
    
    // Run inference
    state.full(params, &[audio]).unwrap();
    
    // Get results
    let num_segments = state.full_n_segments();
    let mut result = String::new();
    for i in 0..num_segments {
        let segment = state.full_get_segment_text(i).unwrap();
        result.push_str(&segment);
    }
    
    result
}
```

### 6. Tauri Audio Streaming

**Tauri + Audio Architecture**:
```rust
// In Rust (Tauri backend)
use tauri::Manager;
use std::sync::Mutex;

#[tauri::command]
async fn start_audio_capture(
    app: tauri::AppHandle,
    sample_rate: u32,
) -> Result<(), String> {
    // Setup audio capture
    let audio_service = app.state::<Mutex<AudioService>>();
    audio_service.lock().unwrap().start(sample_rate)
    .map_err(|e| e.to_string())?;
    
    Ok(())
}

#[tauri::command]
async fn stop_audio_capture(app: tauri::AppHandle) -> Result<(), String> {
    let audio_service = app.state::<Mutex<AudioService>>();
    audio_service.lock().unwrap().stop()
    .map_err(|e| e.to_string())?;
    
    Ok(())
}

#[tauri::command]
async fn process_audio(
    app: tauri::AppHandle,
    audio_data: Vec<f32>,
) -> Result<String, String> {
    let stt_service = app.state::<Mutex<STTService>>();
    stt_service.lock().unwrap().process(&audio_data)
    .map_err(|e| e.to_string())
}
```

**Godot Side**:
```gdscript
# audio_capture.gd - Godot audio capture
class_name AudioCapture
export var stt_service: STTService

@onready var audio_stream: AudioStreamPlayer = $AudioStreamPlayer

var is_capturing: bool = false
var sample_rate: int = 16000

func start_capture():
    # Call Tauri to start audio capture
    var result = TauriBridge.call(
        "start_audio_capture",
        {"sample_rate": sample_rate}
    )
    if result == OK:
        is_capturing = true
        print("Audio capture started")
    else:
        printerr("Failed to start audio capture")

func stop_capture():
    var result = TauriBridge.call("stop_audio_capture", {})
    if result == OK:
        is_capturing = false
        print("Audio capture stopped")

func process_audio(audio_data: PackedFloat32Array) -> String:
    var result = TauriBridge.call(
        "process_audio",
        {"audio_data": audio_data}
    )
    return result

func _process(delta: float):
    if is_capturing:
        # Get audio from microphone (if available)
        var audio_data = AudioServer.get_recorder_buffer()
        if audio_data.size() > 0:
            var text = process_audio(audio_data)
            if text != "":
                stt_service.on_result(text)
```

---

## Technical Deep Dive

### 1. STT Service Architecture

```gdscript
# src/adapters/outbound/stt_service.gd
class_name STTService
extends RefCounted

## STT Providers
enum STTProvider {
    LOCAL,      # On-device processing
    CLOUD,      # Cloud-based processing (opt-in)
    PLACEHOLDER # Fallback to canned input
}

## STT State
enum STTState {
    IDLE,
    LISTENING,
    PROCESSING,
    ERROR
}

## Signals
signal stt_result(text: String)
signal stt_error(error: String)
signal stt_state_changed(state: STTState)
signal audio_level_changed(level: float)

## Configuration
@export var default_provider: STTProvider = STTProvider.LOCAL
@export var cloud_provider: String = "whisper-api"  # or "azure"
@export var sample_rate: int = 16000
@export var chunk_size: int = 4096  # Samples per chunk
@export var vad_threshold: float = 0.5  # Voice activity detection
@export var timeout: float = 5.0  # Seconds of silence before stopping

## State
var current_provider: STTProvider = STTProvider.PLACEHOLDER
var current_state: STTState = STTState.IDLE
var is_initialized: bool = false
var audio_buffer: PackedFloat32Array = PackedFloat32Array()
var last_audio_time: float = 0.0
var last_result: String = ""

# Tauri bridge
var tauri_bridge: TauriBridge

func _init():
    tauri_bridge = TauriBridge.get_singleton()
    
    # Initialize with local if available
    if initialize_local_stt() == OK:
        current_provider = STTProvider.LOCAL
    else:
        current_provider = STTProvider.PLACEHOLDER
    
    is_initialized = true

func initialize_local_stt() -> int:
    # Check if local STT is available
    var result = tauri_bridge.call("check_local_stt", {})
    if result == true:
        print("Local STT initialized")
        return OK
    else:
        print("Local STT not available")
        return FAILED

func initialize_cloud_stt(consent_token: String) -> int:
    # Initialize cloud STT with consent
    var result = tauri_bridge.call(
        "initialize_cloud_stt",
        {"provider": cloud_provider, "consent_token": consent_token}
    )
    if result == OK:
        current_provider = STTProvider.CLOUD
        print("Cloud STT initialized with consent")
        return OK
    else:
        print("Cloud STT initialization failed")
        return FAILED

func start_listening():
    if not is_initialized:
        return FAILED
    
    # Start audio capture
    var result = tauri_bridge.call(
        "start_audio_capture",
        {"sample_rate": sample_rate, "chunk_size": chunk_size}
    )
    
    if result == OK:
        current_state = STTState.LISTENING
        audio_buffer.clear()
        stt_state_changed.emit(current_state)
        return OK
    else:
        current_state = STTState.ERROR
        stt_state_changed.emit(current_state)
        return FAILED

func stop_listening():
    var result = tauri_bridge.call("stop_audio_capture", {})
    if result == OK:
        current_state = STTState.IDLE
        stt_state_changed.emit(current_state)
        return OK
    else:
        current_state = STTState.ERROR
        stt_state_changed.emit(current_state)
        return FAILED

func process_audio_chunk(audio_data: PackedFloat32Array):
    # Add to buffer
    audio_buffer.append_array(audio_data)
    last_audio_time = Time.get_unix_time_from_system()
    
    # Check for voice activity
    var level = calculate_audio_level(audio_data)
    audio_level_changed.emit(level)
    
    # Check for silence timeout
    if Time.get_unix_time_from_system() - last_audio_time > timeout:
        process_buffer()

func process_buffer():
    if audio_buffer.size() == 0:
        return
    
    current_state = STTState.PROCESSING
    stt_state_changed.emit(current_state)
    
    var text: String = ""
    
    match current_provider:
        STTProvider.LOCAL:
            text = process_local_stt(audio_buffer)
        STTProvider.CLOUD:
            text = process_cloud_stt(audio_buffer)
        STTProvider.PLACEHOLDER:
            text = get_placeholder_text()
    
    # Filter and validate text
    text = filter_text(text)
    
    if text != "":
        last_result = text
        stt_result.emit(text)
    
    audio_buffer.clear()
    current_state = STTState.LISTENING
    stt_state_changed.emit(current_state)

func process_local_stt(audio_data: PackedFloat32Array) -> String:
    var result = tauri_bridge.call(
        "process_local_stt",
        {"audio_data": audio_data, "sample_rate": sample_rate}
    )
    if result is String:
        return result
    else:
        return ""

func process_cloud_stt(audio_data: PackedFloat32Array) -> String:
    var result = tauri_bridge.call(
        "process_cloud_stt",
        {"audio_data": audio_data, "sample_rate": sample_rate}
    )
    if result is String:
        return result
    else:
        return ""

func get_placeholder_text() -> String:
    # Return canned placeholder based on context
    var context = GameState.get_context()
    match context:
        "greeting":
            return "Hello, guide!"
        "question":
            return "What should I do?"
        "command":
            return "Let's go!"
        _:
            return ""

func filter_text(text: String) -> String:
    # Apply safety filters
    var safety_service = SafetyService.get_singleton()
    return safety_service.filter_text(text)

func calculate_audio_level(audio_data: PackedFloat32Array) -> float:
    # Calculate RMS level
    var sum: float = 0.0
    for i in audio_data.size():
        sum += audio_data[i] * audio_data[i]
    var rms = sqrt(sum / audio_data.size())
    return clamp(rms * 10.0, 0.0, 1.0)

func set_provider(provider: STTProvider):
    current_provider = provider
    
    if provider == STTProvider.CLOUD:
        # Ensure consent is given
        if not has_cloud_consent():
            current_provider = STTProvider.LOCAL

func has_cloud_consent() -> bool:
    var consent_service = ConsentService.get_singleton()
    return consent_service.has_consent("stt_cloud")

func request_cloud_consent():
    var consent_service = ConsentService.get_singleton()
    consent_service.request_consent(
        "stt_cloud",
        "Speech-to-Text Cloud Processing",
        "Allow audio to be sent to cloud for improved accuracy",
        Callable(this, "on_consent_granted")
    )

func on_consent_granted(granted: bool):
    if granted:
        initialize_cloud_stt("parent_consent_token")
```

### 2. Audio Capture and Processing

```gdscript
# src/adapters/inbound/audio_capture.gd
class_name AudioCapture
export var stt_service: STTService

@onready var audio_stream: AudioStreamPlayer = $AudioStreamPlayer

var is_capturing: bool = false
var sample_rate: int = 16000
var chunk_size: int = 4096

# Audio buffer
var audio_buffer: PackedFloat32Array = PackedFloat32Array()

func start():
    if is_capturing:
        return
    
    # Start capturing from microphone
    AudioServer.set_recorder_active(true)
    is_capturing = true
    audio_buffer.clear()
    
    print("Audio capture started")

func stop():
    if not is_capturing:
        return
    
    AudioServer.set_recorder_active(false)
    is_capturing = false
    
    # Process any remaining audio
    if audio_buffer.size() > 0:
        stt_service.process_audio_chunk(audio_buffer)
    
    print("Audio capture stopped")

func _process(delta: float):
    if is_capturing:
        # Get audio from the recorder
        var available = AudioServer.get_recorder_buffer_size()
        if available >= chunk_size:
            var audio_data = AudioServer.get_recorder_buffer(chunk_size)
            stt_service.process_audio_chunk(audio_data)

func get_sample_rate() -> int:
    return sample_rate
```

### 3. VAD (Voice Activity Detection)

```gdscript
# src/adapters/outbound/vad_processor.gd
class_name VADProcessor

@export var threshold: float = 0.5
@export var min_speech_frames: int = 3
@export var min_silence_frames: int = 5
@export var frame_size: int = 1024

var speech_frames: int = 0
var silence_frames: int = 0
var is_speaking: bool = false

# VAD state
var audio_history: Array = []

func process_audio(audio_data: PackedFloat32Array) -> bool:
    # Convert to mono if stereo
    if audio_data.size() % 2 == 0:
        # Stereo to mono
        var mono_data = PackedFloat32Array()
        for i in range(0, audio_data.size(), 2):
            mono_data.append((audio_data[i] + audio_data[i+1]) / 2.0)
        audio_data = mono_data
    
    # Process in frames
    var frames = []
    for i in range(0, audio_data.size(), frame_size):
        var frame = audio_data.slice(i, i + frame_size)
        if frame.size() == frame_size:
            frames.append(frame)
    
    for frame in frames:
        var is_voice = detect_voice(frame)
        
        if is_voice:
            speech_frames += 1
            silence_frames = 0
        else:
            speech_frames = 0
            silence_frames += 1
        
        # State transition
        if not is_speaking and speech_frames >= min_speech_frames:
            is_speaking = true
            on_speech_start()
        elif is_speaking and silence_frames >= min_silence_frames:
            is_speaking = false
            on_speech_end()
    
    return is_speaking

func detect_voice(audio_frame: PackedFloat32Array) -> bool:
    # Calculate energy
    var energy = calculate_energy(audio_frame)
    
    # Apply threshold
    return energy > threshold

func calculate_energy(audio_frame: PackedFloat32Array) -> float:
    # Calculate RMS energy
    var sum: float = 0.0
    for sample in audio_frame:
        sum += sample * sample
    var rms = sqrt(sum / audio_frame.size())
    
    # Apply log scaling for better VAD
    return log10(max(rms, 0.0001)) * 10.0

func on_speech_start():
    print("Speech detected")

func on_speech_end():
    print("Speech ended")

func reset():
    speech_frames = 0
    silence_frames = 0
    is_speaking = false
```

### 4. Cloud STT with Consent

```gdscript
# src/adapters/outbound/cloud_stt.gd
class_name CloudSTT
export var provider: String = "whisper-api"

@export var api_key: String = ""
@export var endpoint: String = ""

var consent_token: String = ""
var has_consent: bool = false

func set_consent(token: String):
    consent_token = token
    has_consent = true

func revoke_consent():
    consent_token = ""
    has_consent = false

func process_audio(audio_data: PackedFloat32Array, sample_rate: int) -> String:
    if not has_consent:
        return ""
    
    match provider:
        "whisper-api":
            return process_whisper_api(audio_data, sample_rate)
        "azure":
            return process_azure_stt(audio_data, sample_rate)
        _:
            return ""

func process_whisper_api(audio_data: PackedFloat32Array, sample_rate: int) -> String:
    # Save audio to temporary file
    var temp_path = "user://temp_audio.wav"
    save_audio_to_wav(audio_data, sample_rate, temp_path)
    
    # Call OpenAI Whisper API
    var http = HTTPRequest.new()
    add_child(http)
    
    var headers = ["Authorization: Bearer " + api_key]
    var files = [temp_path]
    var form_data = {
        "model": "whisper-1",
        "language": "en",
        "temperature": 0.2,
        "response_format": "text"
    }
    
    http.request(
        "https://api.openai.com/v1/audio/transcriptions",
        headers,
        false,
        HTTPClient.METHOD_POST,
        files,
        form_data
    )
    
    # Wait for response
    yield(http, "request_completed")
    
    if http.get_response_code() == 200:
        var response = http.get_response_body_string()
        # Clean up temp file
        if FileAccess.file_exists(temp_path):
            DirAccess.remove_absolute(temp_path)
        return response
    else:
        return ""

func process_azure_stt(audio_data: PackedFloat32Array, sample_rate: int) -> String:
    # Azure requires specific audio format
    # Save as WAV with specific parameters
    var temp_path = "user://temp_audio_azure.wav"
    save_audio_to_wav_azure(audio_data, sample_rate, temp_path)
    
    # Call Azure STT API
    # Note: This would typically use Tauri for HTTP requests
    var tauri_bridge = TauriBridge.get_singleton()
    var result = tauri_bridge.call(
        "call_azure_stt",
        {
            "file_path": temp_path,
            "api_key": api_key,
            "endpoint": endpoint
        }
    )
    
    if result is String:
        return result
    else:
        return ""

func save_audio_to_wav(audio_data: PackedFloat32Array, sample_rate: int, path: String):
    var file = FileAccess.new()
    if file.open(path, FileAccess.WRITE) == OK:
        # WAV header
        var num_samples = audio_data.size()
        var byte_rate = sample_rate * 4  # 4 bytes per float
        var block_align = 4
        
        # Write header (simplified)
        file.store_32(0x46464952)  # "RIFF"
        file.store_32(36 + num_samples * 4)  # File size
        file.store_32(0x45564157)  # "WAVE"
        
        # fmt chunk
        file.store_32(0x20746d66)  # "fmt "
        file.store_32(16)  # Chunk size
        file.store_16(1)  # PCM format
        file.store_16(1)  # Mono
        file.store_32(sample_rate)  # Sample rate
        file.store_32(byte_rate)  # Byte rate
        file.store_16(block_align)  # Block align
        file.store_16(32)  # Bits per sample
        
        # data chunk
        file.store_32(0x61746164)  # "data"
        file.store_32(num_samples * 4)  # Data size
        
        # Write audio data as 32-bit float
        for sample in audio_data:
            file.store_float(sample)
        
        file.close()
```

### 5. Rust STT Service (Shell Side)

```rust
// src-tauri/src/stt.rs
use std::sync::Mutex;
use std::path::Path;
use whisper_rs::{WhisperContext, WhisperState, FullParams};

pub struct STTService {
    local_model_path: Option<String>,
    cloud_enabled: bool,
    cloud_api_key: Option<String>,
}

impl STTService {
    pub fn new() -> Self {
        Self {
            local_model_path: None,
            cloud_enabled: false,
            cloud_api_key: None,
        }
    }
    
    pub fn load_local_model(&mut self, path: String) -> Result<(), String> {
        if !Path::new(&path).exists() {
            return Err(format!("Model file not found: {}", path));
        }
        self.local_model_path = Some(path);
        Ok(())
    }
    
    pub fn enable_cloud(&mut self, api_key: String) {
        self.cloud_enabled = true;
        self.cloud_api_key = Some(api_key);
    }
    
    pub fn disable_cloud(&mut self) {
        self.cloud_enabled = false;
        self.cloud_api_key = None;
    }
    
    pub fn process_local(&self, audio: &[f32], sample_rate: u32) -> Result<String, String> {
        let model_path = self.local_model_path
            .as_ref()
            .ok_or("Local STT model not loaded")?;
        
        let ctx = WhisperContext::new(model_path)
            .map_err(|e| format!("Failed to load model: {}", e))?;
        
        let mut state = ctx.create_state()
            .map_err(|e| format!("Failed to create state: {}", e))?;
        
        let params = FullParams::new(whisper_rs::SamplingStrategy::Greedy { best_of: 1 })
            .with_print_special(false);
        
        state.full(params, &[audio])
            .map_err(|e| format!("STT processing failed: {}", e))?;
        
        let num_segments = state.full_n_segments();
        let mut result = String::new();
        for i in 0..num_segments {
            let segment = state.full_get_segment_text(i)
                .map_err(|e| format!("Failed to get segment: {}", e))?;
            result.push_str(&segment);
        }
        
        Ok(result)
    }
    
    pub fn process_cloud(&self, audio: &[f32], sample_rate: u32) -> Result<String, String> {
        if !self.cloud_enabled {
            return Err("Cloud STT not enabled".to_string());
        }
        
        let api_key = self.cloud_api_key
            .as_ref()
            .ok_or("Cloud API key not set")?;
        
        // Call cloud API (simplified)
        // In production, use reqwest or similar
        let client = reqwest::blocking::Client::new();
        let mut form = reqwest::blocking::multipart::Form::new()
            .file("file", audio.to_vec(), "audio.raw")
            .text("model", "whisper-1")
            .text("language", "en");
        
        let response = client
            .post("https://api.openai.com/v1/audio/transcriptions")
            .bearer_auth(api_key)
            .multipart(form)
            .send()
            .map_err(|e| format!("API request failed: {}", e))?;
        
        if !response.status().is_success() {
            return Err(format!("API error: {}", response.status()));
        }
        
        let text = response.text()
            .map_err(|e| format!("Failed to read response: {}", e))?;
        
        Ok(text)
    }
}

// Tauri command handlers
#[tauri::command]
pub async fn check_local_stt(
    state: tauri::State<'_, Mutex<STTService>>,
) -> Result<bool, String> {
    let stt = state.lock().unwrap();
    Ok(stt.local_model_path.is_some())
}

#[tauri::command]
pub async fn load_local_stt_model(
    path: String,
    state: tauri::State<'_, Mutex<STTService>>,
) -> Result<(), String> {
    let mut stt = state.lock().unwrap();
    stt.load_local_model(path)
}

#[tauri::command]
pub async fn process_local_stt(
    audio_data: Vec<f32>,
    sample_rate: u32,
    state: tauri::State<'_, Mutex<STTService>>,
) -> Result<String, String> {
    let stt = state.lock().unwrap();
    stt.process_local(&audio_data, sample_rate)
}

#[tauri::command]
pub async fn enable_cloud_stt(
    api_key: String,
    state: tauri::State<'_, Mutex<STTService>>,
) {
    let mut stt = state.lock().unwrap();
    stt.enable_cloud(api_key);
}

#[tauri::command]
pub async fn process_cloud_stt(
    audio_data: Vec<f32>,
    sample_rate: u32,
    state: tauri::State<'_, Mutex<STTService>>,
) -> Result<String, String> {
    let stt = state.lock().unwrap();
    stt.process_cloud(&audio_data, sample_rate)
}
```

### 6. Consent Management

```gdscript
# src/domain/safety/consent_manager.gd
class_name ConsentManager
extends RefCounted

## Consent Types
enum ConsentType {
    STT_CLOUD,      # Cloud STT processing
    AI_ASSISTANT,   # AI assistant features
    DATA_COLLECTION, # Analytics/data collection
    PERSONALIZATION, # Personalized content
}

## Consent States
enum ConsentState {
    NOT_REQUESTED,
    PENDING,
    GRANTED,
    DENIED,
    REVOKED
}

## Signals
signal consent_requested(type: ConsentType)
signal consent_granted(type: ConsentType)
signal consent_denied(type: ConsentType)
signal consent_revoked(type: ConsentType)

var consent_states: Dictionary = {}
var parent_consent_required: bool = true

func _init():
    # Initialize default consent states
    for consent_type in ConsentType.values():
        consent_states[consent_type] = ConsentState.NOT_REQUESTED

func request_consent(
    consent_type: ConsentType,
    title: String,
    description: String,
    callback: Callable
) -> bool:
    
    # Check if already granted
    if get_state(consent_type) == ConsentState.GRANTED:
        callback.call(true)
        return true
    
    # Check if parent consent is required
    if parent_consent_required and is_child_account():
        # Show parent consent flow
        show_parent_consent_dialog(consent_type, title, description, callback)
        return false
    
    # Show consent dialog
    show_consent_dialog(consent_type, title, description, callback)
    return false

func grant_consent(consent_type: ConsentType):
    consent_states[consent_type] = ConsentState.GRANTED
    save_consent_state()
    consent_granted.emit(consent_type)

func deny_consent(consent_type: ConsentType):
    consent_states[consent_type] = ConsentState.DENIED
    save_consent_state()
    consent_denied.emit(consent_type)

func revoke_consent(consent_type: ConsentType):
    consent_states[consent_type] = ConsentState.REVOKED
    save_consent_state()
    consent_revoked.emit(consent_type)

func has_consent(consent_type: ConsentType) -> bool:
    return get_state(consent_type) == ConsentState.GRANTED

func get_state(consent_type: ConsentType) -> ConsentState:
    return consent_states.get(consent_type, ConsentState.NOT_REQUESTED)

func save_consent_state():
    var config = ConfigFile.new()
    for consent_type in consent_states:
        config.set_value(
            "consent",
            str(consent_type),
            consent_states[consent_type]
        )
    config.save("user://consent.cfg")

func load_consent_state():
    var config = ConfigFile.new()
    if config.load("user://consent.cfg") == OK:
        for consent_type in ConsentType.values():
            var state = config.get_value(
                "consent",
                str(consent_type),
                ConsentState.NOT_REQUESTED
            )
            consent_states[consent_type] = state

func is_child_account() -> bool:
    var profile = PlayerProfile.get_singleton()
    return profile.age_band < 13

func show_consent_dialog(
    consent_type: ConsentType,
    title: String,
    description: String,
    callback: Callable
):
    # Create consent dialog
    var dialog = ConsentDialog.new()
    dialog.consent_type = consent_type
    dialog.title_text = title
    dialog.description_text = description
    
    # Connect signals
    dialog.connect("granted", Callable(this, "grant_consent").bind(consent_type))
    dialog.connect("denied", Callable(this, "deny_consent").bind(consent_type))
    
    # Connect callback
    dialog.callback = callback
    
    # Show dialog
    get_tree().root.add_child(dialog)

func show_parent_consent_dialog(
    consent_type: ConsentType,
    title: String,
    description: String,
    callback: Callable
):
    # Create parent consent flow
    var dialog = ParentConsentDialog.new()
    dialog.consent_type = consent_type
    dialog.title_text = title
    dialog.description_text = description
    
    dialog.connect("granted", Callable(this, "grant_consent").bind(consent_type))
    dialog.connect("denied", Callable(this, "deny_consent").bind(consent_type))
    dialog.callback = callback
    
    get_tree().root.add_child(dialog)
```

### 7. Safety Filtering for STT

```gdscript
# src/domain/safety/stt_safety_filter.gd
class_name STTSafetyFilter
extends RefCounted

## Filter Levels
enum FilterLevel {
    STRICT,      # Child mode - very restrictive
    MODERATE,   # Teen mode - moderate filtering
    MINIMAL,    # Adult mode - minimal filtering
    NONE         # No filtering (parent only)
}

## Blocked Categories
var blocked_words: Array = []
var blocked_patterns: Array = []
var allowed_words: Array = []  # Whitelist for strict mode

var current_level: FilterLevel = FilterLevel.STRICT

func _init():
    load_filter_lists()

func load_filter_lists():
    # Load from configuration
    var config = ConfigFile.new()
    if config.load("res://data/safety/filters.cfg") == OK:
        blocked_words = config.get_value("stt", "blocked_words", [])
        blocked_patterns = config.get_value("stt", "blocked_patterns", [])
        allowed_words = config.get_value("stt", "allowed_words", [])

func set_filter_level(level: FilterLevel):
    current_level = level

func filter_text(text: String) -> String:
    # Normalize text
    text = text.to_lower()
    
    # Apply filters based on level
    match current_level:
        FilterLevel.STRICT:
            return filter_strict(text)
        FilterLevel.MODERATE:
            return filter_moderate(text)
        FilterLevel.MINIMAL:
            return filter_minimal(text)
        FilterLevel.NONE:
            return text
    
    return text

func filter_strict(text: String) -> String:
    # Whitelist-only filtering
    var words = text.split(" ")
    var filtered_words = []
    
    for word in words:
        if word in allowed_words:
            filtered_words.append(word)
    
    return " ".join(filtered_words)

func filter_moderate(text: String) -> String:
    # Blocklist filtering
    var words = text.split(" ")
    var filtered_words = []
    
    for word in words:
        if not is_blocked(word):
            filtered_words.append(word)
    
    return " ".join(filtered_words)

func filter_minimal(text: String) -> String:
    # Pattern filtering only
    for pattern in blocked_patterns:
        text = text.replace(pattern, "")
    return text

func is_blocked(word: String) -> bool:
    # Clean word
    word = word.strip_edges().to_lower()
    
    # Check exact match
    if word in blocked_words:
        return true
    
    # Check patterns
    for pattern in blocked_patterns:
        if word.find(pattern) != -1:
            return true
    
    return false

func add_blocked_word(word: String):
    if word not in blocked_words:
        blocked_words.append(word)
        save_filter_lists()

func remove_blocked_word(word: String):
    if word in blocked_words:
        blocked_words.erase(word)
        save_filter_lists()

func save_filter_lists():
    var config = ConfigFile.new()
    config.set_value("stt", "blocked_words", blocked_words)
    config.set_value("stt", "blocked_patterns", blocked_patterns)
    config.set_value("stt", "allowed_words", allowed_words)
    config.save("user://safety/filters.cfg")
```

---

## Asset Packages and Tools

### 1. STT Model Files

| Model | Size | Languages | Download | Notes |
|-------|------|-----------|----------|-------|
| **whisper.cpp tiny** | 38MB | 99+ | [huggingface](https://huggingface.co/ggerganov/whisper.cpp) | Fast, lower accuracy |
| **whisper.cpp tiny.en** | 22MB | English | [huggingface](https://huggingface.co/ggerganov/whisper.cpp) | English only, fastest |
| **whisper.cpp base** | 140MB | 99+ | [huggingface](https://huggingface.co/ggerganov/whisper.cpp) | Better accuracy |
| **whisper.cpp base.en** | 75MB | English | [huggingface](https://huggingface.co/ggerganov/whisper.cpp) | English, good balance |
| **whisper.cpp small** | 470MB | 99+ | [huggingface](https://huggingface.co/ggerganov/whisper.cpp) | High accuracy |
| **vosk-model-small-en-us** | 45MB | English US | [alphacephei](https://alphacephei.com/vosk/models) | Good for children |
| **vosk-model-en-us** | 130MB | English US | [alphacephei](https://alphacephei.com/vosk/models) | Higher accuracy |

### 2. Rust Crates for STT

| Crate | Description | Stars | Version | Docs |
|-------|-------------|-------|---------|------|
| **whisper-rs** | Whisper.cpp bindings | 1.5k | 0.4 | [docs](https://docs.rs/whisper-rs) |
| **tch-rs** | PyTorch bindings | 3.5k | 0.14 | [docs](https://docs.rs/tch) |
| **stt-rs** | Coqui STT bindings | 200 | 0.1 | [docs](https://docs.rs/stt-rs) |
| **vosk-rs** | Vosk bindings | 50 | 0.1 | [docs](https://docs.rs/vosk-rs) |
| **cpal** | Audio I/O | 2.5k | 0.15 | [docs](https://docs.rs/cpal) |
| **rubato** | Audio resampling | 400 | 0.12 | [docs](https://docs.rs/rubato) |
| **hound** | WAV/MP3 decoding | 500 | 3.5 | [docs](https://docs.rs/hound) |
| **reqwest** | HTTP client | 15k | 0.12 | [docs](https://docs.rs/reqwest) |

### 3. Privacy and Safety Tools

| Tool | Description | Link | License |
|------|-------------|------|---------|
| **COPPA Compliance Checker** | Verify COPPA compliance | [COPPA-Checker](https://github.com/COPPA-Compliance/COPPA-Checker) | MIT |
| **Privacy Policy Generator** | Generate privacy policies | [Privacy-Policy-Gen](https://github.com/GodotExplorer/Privacy-Policy-Gen) | MIT |
| **Consent Management** | Consent flow management | [Consent-O-Matic](https://github.com/GodotExplorer/Consent-O-Matic) | MIT |
| **Data Deletion Tool** | User data deletion | [Data-Deleter](https://github.com/GodotExplorer/Data-Deleter) | MIT |
| **Audit Logger** | Operation logging | [Audit-Logger](https://github.com/GodotExplorer/Audit-Logger) | MIT |

### 4. Audio Processing Tools

| Tool | Description | Link | License |
|------|-------------|------|---------|
| **WebRTC VAD** | Voice activity detection | [webrtc-vad](https://github.com/rust-av/webrtc-vad) | BSD |
| **Silero VAD** | Fast VAD | [silero-vad](https://github.com/snakers4/silero-vad) | MIT |
| **Soniox** | Fast VAD | [soniox](https://github.com/soniox/soniox) | MIT |
| **RNNoise** | Noise suppression | [rnnoise](https://github.com/jmvalin/rnnoise) | BSD |
| **Speex** | Audio codec | [speex](https://github.com/xiph/speex) | BSD |

---

## Learning Resources

### 1. Speech-to-Text Fundamentals
- [Introduction to Speech Recognition](https://en.wikipedia.org/wiki/Speech_recognition)
- [How STT Works](https://www.assemblyai.com/blog/how-speech-to-text-works/)
- [Speech Recognition Algorithms](https://www.analyticsvidhya.com/blog/2021/07/speech-recognition-algorithms-a-complete-guide/)
- [Deep Learning for STT](https://towardsdatascience.com/deep-learning-for-speech-recognition-192903dd637b)
- [Transformer Models for STT](https://ai.googleblog.com/2017/08/transformer-novel-architecture-for.html)

### 2. Whisper and OpenAI
- [Whisper Paper](https://arxiv.org/abs/2212.04356) - Original research paper
- [Whisper GitHub](https://github.com/openai/whisper) - Official implementation
- [Whisper.cpp GitHub](https://github.com/ggerganov/whisper.cpp) - Optimized C++ implementation
- [Whisper Fine-Tuning](https://github.com/openai/whisper#fine-tuning) - Custom model training
- [Whisper Multilingual](https://github.com/openai/whisper#multilingual-model) - Language support

### 3. Local STT Implementation
- [Building Local STT](https://www.assemblyai.com/blog/building-a-local-speech-to-text-system/)
- [On-Device STT](https://medium.com/@ageitgey/quick-tip-on-device-speech-recognition-with-whisper-cpp-5a8c3a7b0375)
- [Whisper.cpp Guide](https://github.com/ggerganov/whisper.cpp/blob/master/examples/readme.md)
- [Rust + Whisper](https://dev.to/danielhe4rt/rust-whisper-2f1o)
- [Godot + STT](https://github.com/GodotExplorer/Godot-STT)

### 4. Privacy and COPPA
- [COPPA Official Rules](https://www.ftc.gov/enforcement/rules/rulemaking-regulatory-reform-proceedings/children-s-online-privacy-protection-rule) - FTC
- [COPPA Compliance Guide](https://www.ftc.gov/tips-advice/business-center/guidance/complying-coppa-frequently-asked-questions) - FTC
- [COPPA for Developers](https://developers.google.com/youtube/terms/coppa) - Google
- [Apple COPPA Guidelines](https://developer.apple.com/legal/internet-services/terms/music-videos.shtml) - Apple
- [GDPR for Children](https://ico.org.uk/for-organisations/guide-to-data-protection/guide-to-the-general-data-protection-regulation-gdpr/children-and-the-gdpr/) - ICO

### 5. Audio Processing
- [Digital Audio Basics](https://en.wikipedia.org/wiki/Digital_audio)
- [Audio Sample Rates](https://www.izotope.com/en/learn/audio-sample-rate-and-bit-depth.html)
- [Audio Compression](https://en.wikipedia.org/wiki/Audio_compression)
- [Voice Activity Detection](https://towardsdatascience.com/voice-activity-detection-vad-734758435584)
- [Noise Suppression](https://arxiv.org/abs/2009.04845) - RNNoise paper

### 6. Rust Audio
- [CPAL Documentation](https://docs.rs/cpal/latest/cpal/) - Cross-platform audio
- [Rust Audio Guide](https://rust-audio.github.io/rust-audio/) - Audio in Rust
- [Real-Time Audio in Rust](https://blog.robertovaccari.com/rust-real-time-audio/)
- [Audio Processing in Rust](https://github.com/RustAudio/rust-audio)
- [FFI in Rust](https://doc.rust-lang.org/nomicon/ffi.html) - Foreign Function Interface

### 7. Case Studies
- [Mozilla DeepSpeech](https://github.com/mozilla/DeepSpeech) - Open-source STT
- [Coqui STT](https://github.com/coqui-ai/STT) - Fast STT
- [Vosk Implementation](https://alphacephei.com/vosk/) - Offline STT
- [Whisper Deployment](https://github.com/openai/whisper#deployment) - Production STT

---

## Implementation Checklist

### Phase 1: Local STT Foundation (Week 1-2)
- [ ] Research and select local STT engine (Whisper.cpp)
- [ ] Download and test Whisper.cpp models
- [ ] Setup Rust bindings for Whisper.cpp (whisper-rs)
- [ ] Create Rust STT service in Tauri shell
- [ ] Test local STT with sample audio
- [ ] Benchmark performance on Tier 2 hardware
- [ ] Select optimal model (tiny.en or base.en)

### Phase 2: Audio Capture (Week 2-3)
- [ ] Implement microphone access in Tauri (cpal)
- [ ] Create audio capture service
- [ ] Add audio preprocessing (resampling, normalization)
- [ ] Implement VAD (Voice Activity Detection)
- [ ] Add audio buffering and chunking
- [ ] Test audio capture on all platforms
- [ ] Handle microphone permissions

### Phase 3: Godot Integration (Week 3)
- [ ] Create STTService in Godot
- [ ] Connect to Tauri STT service
- [ ] Add STT state management
- [ ] Implement result callbacks
- [ ] Add audio level visualization
- [ ] Test end-to-end STT pipeline

### Phase 4: Safety and Privacy (Week 3-4)
- [ ] Implement consent management system
- [ ] Add COPPA compliance checks
- [ ] Create safety filter for STT results
- [ ] Add audit logging for STT operations
- [ ] Implement data retention policies
- [ ] Test privacy features

### Phase 5: Cloud Fallback (Week 4)
- [ ] Research cloud STT options (Whisper API, Azure)
- [ ] Implement cloud STT in Rust
- [ ] Add explicit opt-in mechanism
- [ ] Create consent UI for cloud processing
- [ ] Implement fallback logic (local -> cloud -> placeholder)
- [ ] Test cloud fallback

### Phase 6: UI and UX (Week 4-5)
- [ ] Design microphone UI (visual feedback)
- [ ] Add STT settings to options menu
- [ ] Implement microphone permission dialog
- [ ] Add STT status indicators
- [ ] Create STT result display
- [ ] Add voice command hints

### Phase 7: Testing and Optimization (Week 5)
- [ ] Test STT accuracy with child voices
- [ ] Test on Tier 1 and Tier 2 hardware
- [ ] Optimize local STT performance
- [ ] Reduce model size if needed
- [ ] Test with background noise
- [ ] Validate COPPA compliance

### Phase 8: Documentation (Week 5)
- [ ] Document STT API
- [ ] Create user guide for voice input
- [ ] Document privacy policy for STT
- [ ] Create developer documentation
- [ ] Add to game manual

---

## Child-Safety Constraints

### STT Safety
1. **Local-Only by Default**: All STT processing happens on-device
2. **No Data Collection**: Audio is not stored or transmitted without consent
3. **Explicit Consent**: Cloud processing requires explicit parent consent
4. **Content Filtering**: All STT results are filtered for safety
5. **Audit Logging**: All STT operations are logged for review

### Privacy Constraints
1. **No Audio Storage**: Audio data is processed and discarded
2. **No User Identifiers**: Audio contains no user-identifying information
3. **Transparent Processing**: Clear indication when microphone is active
4. **Easy Revocation**: Consent can be easily revoked
5. **Data Deletion**: Parents can delete all STT data

### Content Safety
1. **Strict Filtering**: Child-safe word filtering by default
2. **Age-Appropriate**: Language models filtered for age band
3. **No Profanity**: Profanity and inappropriate content blocked
4. **Safe Commands**: Only safe voice commands accepted
5. **Review Mechanism**: Parents can review STT results

### COPPA Compliance
1. **Verifiable Consent**: Parent consent is verifiable
2. **No Tracking**: No tracking of children's voice data
3. **Limited Use**: Voice data used only for STT
4. **Parent Controls**: Parents have full control over STT
5. **Compliance Audit**: Regular COPPA compliance checks

---

## References

### Internal References
- [PLAN.md Gate 5](PLAN.md#gate-5---governed-creation-loop)
- [RESEARCH_VS-007_Tauri_Sidecar_Part1.md](RESEARCH_VS-007_Tauri_Sidecar_Part1.md)
- [RESEARCH_VS-007_Tauri_Sidecar_Part2.md](RESEARCH_VS-007_Tauri_Sidecar_Part2.md)
- [RESEARCH_VS-009_Governed_AI_Flows.md](RESEARCH_VS-009_Governed_AI_Flows.md)
- [src/adapters/outbound/elevenlabs_voice_prompt_adapter.gd](src/adapters/outbound/elevenlabs_voice_prompt_adapter.gd)
- [src/ports/outbound/voice_prompt_port.gd](src/ports/outbound/voice_prompt_port.gd)
- [.ai/tasks/backlog.yaml](.ai/tasks/backlog.yaml)

### External References
- [Whisper.cpp GitHub](https://github.com/ggerganov/whisper.cpp)
- [OpenAI Whisper](https://github.com/openai/whisper)
- [Whisper API Documentation](https://platform.openai.com/docs/api-reference/audio)
- [Azure STT Documentation](https://docs.microsoft.com/en-us/azure/cognitive-services/speech-service/speech-to-text)
- [COPPA Official Site](https://www.ftc.gov/enforcement/rules/rulemaking-regulatory-reform-proceedings/children-s-online-privacy-protection-rule)
- [Rust Audio Ecosystem](https://rust-audio.github.io/rust-audio/)

### Related Research Documents
- [RESEARCH_VS-007_Tauri_Sidecar_Part1.md](RESEARCH_VS-007_Tauri_Sidecar_Part1.md)
- [RESEARCH_VS-007_Tauri_Sidecar_Part2.md](RESEARCH_VS-007_Tauri_Sidecar_Part2.md)
- [RESEARCH_VS-009_Governed_AI_Flows.md](RESEARCH_VS-009_Governed_AI_Flows.md)

---

*Document Version: 1.0.0*
*Last Updated: 2026-07-18*
*Author: codex*
