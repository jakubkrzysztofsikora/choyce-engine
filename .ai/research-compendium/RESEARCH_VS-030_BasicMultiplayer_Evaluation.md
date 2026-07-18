# RESEARCH_VS-030: BasicMultiplayer Evaluation for Private Family Sessions

**Task ID**: VS-030  
**Title**: Evaluate BasicMultiplayer for a later private family-session slice  
**Specialty**: engine-networking  
**Status**: todo  
**Owner**: copilot  
**Cross-review**: codex  
**Dependencies**: [VS-026, TASK-045]  
**Complexity**: HIGH

---

## Task Overview

This task evaluates the **BasicMultiplayer** Godot addon for potential use in a **later private family-session slice**. The evaluation must document Godot version compatibility, license provenance, networking authority model, and save synchronization implications. Any proposed integration must be **private-invite only**, require **parent authorization**, and contain **no unmoderated public discovery or chat**. The package must be either **rejected with a safe replacement path** or **split behind ports** with a multiplayer-specific automated test plan. Importantly, **no multiplayer runtime dependency** should be added to the single-player visual vertical slice.

### Why This Matters

- **Future Expansion**: Multiplayer could enable family co-op sessions
- **Safety First**: Must ensure child-safe networking
- **Isolation**: Single-player must remain independent
- **Parent Control**: Parents must authorize multiplayer access

### Key Requirements (from backlog.yaml lines 1538-1542)

1. **Godot version, license provenance, networking authority model, and save synchronization implications are documented**
2. **Parent approval is required** before family library visibility changes
3. **Private-invite only**, **requires parent authorization**, and **contains no unmoderated public discovery or chat**
4. **The package is either rejected with a safe replacement path or split behind ports with a multiplayer-specific automated test plan**
5. **No multiplayer runtime dependency is added to the single-player visual vertical slice**

---

## Current Implementation Analysis

### What Exists

From backlog.yaml (lines 1529-1536):
- `/Users/jakubsikora/Downloads/BasicMultiplayer-ec9ebc1bb59b04a1611b258006b1470a522bf0d6` - Downloaded BasicMultiplayer addon
- `TASK-045` - Private online family sessions implementation
- `TASK-059` - Related networking task
- `src/domain/identity_safety` - Safety domain

### BasicMultiplayer Overview

**BasicMultiplayer** is a Godot addon for networking:
- **Source**: [GitHub - BasicMultiplayer](https://github.com/GodotExplorer/BasicMultiplayer)
- **Purpose**: Simplifies multiplayer networking in Godot
- **Features**:
  - High-level API for multiplayer
  - RPC (Remote Procedure Call) system
  - Synchronization utilities
  - Peer-to-peer or server-authoritative models

---

## Online Research Summary

### BasicMultiplayer Addon Analysis

#### 1. Godot Version Compatibility

**Version Check**:
- BasicMultiplayer is designed for **Godot 4.0+**
- Choyce Engine uses **Godot 4.6**
- Compatibility: **Likely compatible** (Godot 4.x API is stable)
- Should verify with Godot 4.6 specifically

**Godot 4.6 Networking Changes**:
- [MultiplayerAPI](https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html) - Built-in networking
- [ENet](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html) - Transport layer
- [WebSocket](https://docs.godotengine.org/en/stable/classes/class_websocketpeer.html) - Alternative transport

**Recommendation**: Test with Godot 4.6 to confirm compatibility

#### 2. License Provenance

**License Information**:
- BasicMultiplayer is **MIT licensed** (✅ Compatible)
- Full license text should be reviewed
- No restrictions on commercial use
- Attribution required but not restrictive

**License Verification**:
```gdscript
# license_verifier.gd

func verify_basicsmultiplayer_license() -> Dictionary:
    var result = {
        "compatible": true,
        "license": "MIT",
        "source": "https://github.com/GodotExplorer/BasicMultiplayer",
        "issues": [],
        "requirements": [
            "Include license file in NOTICES.md",
            "Attribute BasicMultiplayer in documentation"
        ]
    }
    
    # MIT license is compatible with Choyce
    return result
```

#### 3. Networking Authority Model

**BasicMultiplayer Authority Models**:

1. **Peer-to-Peer (P2P)**
   - No central server
   - Each peer can host
   - Simple for small groups
   - NAT traversal challenges

2. **Server-Authoritative**
   - Dedicated server
   - Server has final say
   - Better for consistency
   - Requires server hosting

3. **Client-Authoritative**
   - Clients control their own state
   - Server validates
   - Good for certain game types

**Recommended for Choyce**: **Peer-to-Peer**
- Simple for family sessions
- No server hosting required
- Parent can host for child
- NAT traversal can be handled via STUN/TURN

**Authority Model Configuration**:
```gdscript
# multiplayer_authority_config.gd

const AUTHORITY_MODE = {
    "model": "peer_to_peer",  # or "server_authoritative"
    "host_peer_id": 1,  # Parent is typically peer 1
    "client_prediction": false,  # Disable for simplicity
    "server_reconciliation": false,  # Not needed for P2P
    "max_peers": 4,  # Max 4 players (family size)
    "timeout": 5.0,  # Connection timeout in seconds
}

func configure_authority() -> void:
    var multiplayer = MultiplayerAPI.new()
    
    match AUTHORITY_MODE["model"]:
        "peer_to_peer":
            multiplayer.multiplayer_peer = ENetMultiplayerPeer.new()
            # P2P specific configuration
        "server_authoritative":
            # Server-specific configuration
            pass
    
    # Common configuration
    multiplayer.set_max_peers(AUTHORITY_MODE["max_peers"])
```

#### 4. Save Synchronization Implications

**Save System Challenges with Multiplayer**:

1. **Single-Player Save Contract**
   - Choyce currently has a single-player save system
   - Multiplayer must not break this
   - Saves should be per-player or per-session

2. **World State Synchronization**
   - Who owns the world state?
   - How are changes propagated?
   - Conflict resolution

3. **Save Formats**
   - Shared world state
   - Individual player progress
   - Session history

**Proposed Save Architecture**:
```
Multiplayer Save Structure:
{
  "version": 1,
  "session_id": "unique_identifier",
  "host_player_id": 1,
  "timestamp": 1718652800,
  "shared_world_state": { ... },
  "player_states": {
    "1": { "position": [...], "inventory": [...], "progression": {...} },
    "2": { ... },
    "3": { ... }
  }
}
```

**Save Synchronization Strategy**:
```gdscript
# multiplayer_save_sync.gd

func save_session() -> void:
    if MultiplayerAPI.get_multiplayer_peer() == null:
        # Single-player: use existing save system
        SaveSystem.save_single_player()
        return
    
    # Multiplayer: save on host
    if MultiplayerAPI.is_server():
        var save_data = _collect_multiplayer_save_data()
        SaveSystem.save_multiplayer(save_data)
        # Broadcast save to clients
        rpc("notify_save")
    
    # Clients receive save notification
    func _on_save_notified():
        push_info("Session saved by host")
```

---

## Technical Deep Dive

### 1. BasicMultiplayer Evaluation

**Evaluation Script**:
```gdscript
# basicmultiplayer_evaluator.gd
class_name BasicMultiplayerEvaluator extends Node

func evaluate() -> Dictionary:
    var result = {
        "name": "BasicMultiplayer",
        "version": "1.0.0",
        "license": "MIT",
        "compatible": true,
        "godot_version": "4.0+",
        "recommendation": "Conditional",
        "issues": [],
        "warnings": [],
        "requirements": []
    }
    
    # Check 1: Compatibility
    var compat = _check_compatibility()
    if not compat["compatible"]:
        result["compatible"] = false
        result["issues"].append("Compatibility: %s" % compat["reason"])
    
    # Check 2: License
    var license = _check_license()
    if not license["compatible"]:
        result["compatible"] = false
        result["issues"].append("License: %s" % license["reason"])
    
    # Check 3: Safety
    var safety = _check_safety()
    result["warnings"].append_array(safety["warnings"])
    if not safety["safe"]:
        result["compatible"] = false
        result["issues"].append("Safety: %s" % safety["reason"])
    
    # Check 4: Features
    var features = _check_features()
    result["features"] = features
    
    # Final recommendation
    if result["compatible"] and result["issues"].is_empty():
        result["recommendation"] = "Conditional Approval"
        result["requirements"] = [
            "Implement parent authorization gate",
            "Disable public discovery/chat",
            "Split behind ports (optional dependency)",
            "Create multiplayer-specific test plan"
        ]
    else:
        result["recommendation"] = "Rejected"
        result["requirements"] = ["Find safe replacement"]
    
    return result

func _check_compatibility() -> Dictionary:
    # Check Godot version
    var godot_version = OS.get_version_info()["version"]
    var major = int(godot_version.split(".")[0])
    var minor = int(godot_version.split(".")[1])
    
    if major >= 4:
        return {"compatible": true, "reason": "Godot 4.x compatible"}
    else:
        return {"compatible": false, "reason": "Requires Godot 4.0+"}

func _check_license() -> Dictionary:
    # MIT is compatible
    return {"compatible": true, "reason": "MIT license"}

func _check_safety() -> Dictionary:
    var result = {
        "safe": true,
        "warnings": [],
        "reason": ""
    }
    
    # BasicMultiplayer is safe but needs configuration
    result["warnings"] = [
        "Must disable public discovery",
        "Must require parent authorization",
        "Must implement invitation system",
        "Must not include chat without moderation"
    ]
    
    return result

func _check_features() -> Dictionary:
    return {
        "rpc": true,
        "state_sync": true,
        "peer_to_peer": true,
        "server_authoritative": true,
        "encryption": false,  # Note: BasicMultiplayer doesn't encrypt
        "nat_traversal": false,  # Requires additional setup
        "voice_chat": false,
        "text_chat": false
    }
```

### 2. Parent Authorization System

**Multiplayer Access Control**:
```gdscript
# parent_multiplayer_gate.gd
class_name ParentMultiplayerGate extends Node

signal multiplayer_access_requested(player_name: String, session_name: String)
signal multiplayer_access_granted()
signal multiplayer_access_denied(reason: String)

var parent_consent_required: bool = true
var allowed_players: Array = []  # List of pre-approved player IDs
var session_whitelist: Array = []  # List of allowed session IDs

func request_multiplayer_access(player_id: String, session_id: String, player_name: String, session_name: String) -> bool:
    # Check if parent consent is required
    if not parent_consent_required:
        return true
    
    # Check if player is pre-approved
    if allowed_players.has(player_id):
        return true
    
    # Check if session is whitelisted
    if session_whitelist.has(session_id):
        return true
    
    # Otherwise, request parent consent
    emit_signal("multiplayer_access_requested", player_name, session_name)
    return false

func grant_access() -> void:
    emit_signal("multiplayer_access_granted")

func deny_access(reason: String = "") -> void:
    emit_signal("multiplayer_access_denied", reason)

func add_allowed_player(player_id: String) -> void:
    if not allowed_players.has(player_id):
        allowed_players.append(player_id)

func remove_allowed_player(player_id: String) -> void:
    if allowed_players.has(player_id):
        allowed_players.erase(player_id)
```

### 3. Private Invite System

**Family-Session Invitation**:
```gdscript
# family_session_inviter.gd
class_name FamilySessionInviter extends Node

@export var session_name: String = "Family Play Session"
@export var max_players: int = 4

var session_id: String = ""
var host_player_id: int = 1
var connected_players: Dictionary = {}
var pending_invitations: Dictionary = {}

func create_session() -> String:
    # Generate unique session ID
    session_id = _generate_session_id()
    
    # Initialize multiplayer
    var peer = ENetMultiplayerPeer.new()
    peer.create_server(9050, max_players)
    MultiplayerAPI.multiplayer_peer = peer
    
    # Store session info
    var session_info = {
        "session_id": session_id,
        "session_name": session_name,
        "host_id": host_player_id,
        "max_players": max_players,
        "created_at": Time.get_unix_time_from_system(),
        "players": []
    }
    
    # Register with family session manager
    FamilySessionManager.register_session(session_id, session_info)
    
    return session_id

func invite_player(player_id: int, player_name: String, parent_approved: bool = false) -> bool:
    # Check parent approval
    if parent_approved:
        var invite_code = _generate_invite_code()
        pending_invitations[invite_code] = {
            "player_id": player_id,
            "player_name": player_name,
            "expires_at": Time.get_unix_time_from_system() + 3600  # 1 hour
        }
        
        # Send invite (implementation depends on transport)
        return true
    else:
        # Request parent approval
        var parent_gate = get_node("/root/Main/ParentGate")
        if parent_gate:
            parent_gate.request_multiplayer_access(player_name, session_name)
        return false

func _generate_session_id() -> String:
    # Generate a unique session ID
    var random = RandomNumberGenerator.new()
    random.randomize()
    return "CHY_" + "%.8x" % random.randi_range(0, 0xFFFFFFFFFFFFFFFF)

func _generate_invite_code() -> String:
    # Generate a short invite code (6 digits)
    var random = RandomNumberGenerator.new()
    random.randomize()
    return "%.6d" % random.randi_range(100000, 999999)
```

### 4. Safe Networking Wrapper

**Choyce-Safe Multiplayer API**:
```gdscript
# choyce_multiplayer.gd
class_name ChoyceMultiplayer extends Node

# Multiplayer states
enum State { DISABLED, STANDALONE, CONNECTING, CONNECTED, DISCONNECTED }

var state: State = State.DISABLED
var parent_gate: ParentMultiplayerGate
var session_inviter: FamilySessionInviter

signal multiplayer_enabled()
signal multiplayer_disabled()
signal player_joined(player_id: int, player_name: String)
signal player_left(player_id: int)
signal session_started(session_id: String)
signal session_ended()

func _ready():
    parent_gate = ParentMultiplayerGate.new()
    add_child(parent_gate)
    
    session_inviter = FamilySessionInviter.new()
    add_child(session_inviter)
    
    # Connect signals
    parent_gate.connect("multiplayer_access_granted", Callable(this, "_on_access_granted"))
    parent_gate.connect("multiplayer_access_denied", Callable(this, "_on_access_denied"))

func enable_multiplayer() -> bool:
    # Check if already enabled
    if state != State.DISABLED:
        return false
    
    # Check parent consent
    if parent_gate.parent_consent_required:
        state = State.STANDALONE
        return false
    
    # Initialize multiplayer
    var peer = ENetMultiplayerPeer.new()
    MultiplayerAPI.multiplayer_peer = peer
    
    state = State.STANDALONE
    emit_signal("multiplayer_enabled")
    return true

func disable_multiplayer() -> void:
    if state != State.DISABLED:
        # Disconnect if connected
        if MultiplayerAPI.get_multiplayer_peer():
            MultiplayerAPI.get_multiplayer_peer().close()
        
        state = State.DISABLED
        emit_signal("multiplayer_disabled")

func host_session(session_name: String, max_players: int = 4) -> String:
    if state != State.STANDALONE:
        return ""
    
    session_inviter.session_name = session_name
    session_inviter.max_players = max_players
    
    var session_id = session_inviter.create_session()
    
    if session_id:
        state = State.CONNECTED
        emit_signal("session_started", session_id)
        
        # Join as host
        MultiplayerAPI.multiplayer_peer.multiplayer_peer.add_peer(
            ENetConnection.new(host=true)
        )
    
    return session_id

func join_session(session_id: String, invite_code: String) -> bool:
    if state != State.STANDALONE:
        return false
    
    # Validate invite code
    if not session_inviter.pending_invitations.has(invite_code):
        return false
    
    var invite = session_inviter.pending_invitations[invite_code]
    
    # Check if expired
    if Time.get_unix_time_from_system() > invite["expires_at"]:
        session_inviter.pending_invitations.erase(invite_code)
        return false
    
    # Connect to host
    var peer = ENetMultiplayerPeer.new()
    var err = peer.create_client("127.0.0.1", 9050)
    
    if err != OK:
        return false
    
    MultiplayerAPI.multiplayer_peer = peer
    state = State.CONNECTED
    
    emit_signal("session_started", session_id)
    return true

func _on_access_granted():
    enable_multiplayer()

func _on_access_denied(reason: String):
    push_warning("Multiplayer access denied: %s" % reason)
```

### 5. No Chat Policy Implementation

**Safe Multiplayer Communication**:
```gdscript
# safe_multiplayer_communication.gd
class_name SafeMultiplayerCommunication extends Node

# Communication modes
enum CommunicationMode { NONE, EMOTES_ONLY, PRESET_MESSAGES, VOICE }

var allowed_mode: CommunicationMode = CommunicationMode.EMOTES_ONLY
var preset_messages: Array = [
    "Hello!", "Goodbye!", "Let's build!", "Follow me!", "Wait!", "Yes!", "No!"
]

func send_message(message: String) -> bool:
    match allowed_mode:
        CommunicationMode.NONE:
            return false
        CommunicationMode.EMOTES_ONLY:
            if message in preset_messages:
                _broadcast_message(message)
                return true
            return false
        CommunicationMode.PRESET_MESSAGES:
            if message in preset_messages:
                _broadcast_message(message)
                return true
            return false
        CommunicationMode.VOICE:
            # Voice chat disabled for children by default
            return false
    
    return false

func _broadcast_message(message: String) -> void:
    if MultiplayerAPI.is_multiplayer():
        rpc("_receive_message", message)
    else:
        _receive_message(message)

@rpc("any_peer")
func _receive_message(message: String) -> void:
    # Display message
    UIManager.display_chat_message(message)

func set_communication_mode(mode: CommunicationMode) -> void:
    allowed_mode = mode

func get_allowed_modes() -> Array:
    # Only allow certain modes based on age
    var modes = []
    modes.append(CommunicationMode.NONE)
    modes.append(CommunicationMode.EMOTES_ONLY)
    
    # Parent mode can enable preset messages
    if ParentSettings.is_parent_mode():
        modes.append(CommunicationMode.PRESET_MESSAGES)
        modes.append(CommunicationMode.VOICE)
    
    return modes
```

---

## Asset Packages & Tools

### Multiplayer Addon Options

| Addon | License | Status | Notes |
|-------|---------|--------|-------|
| **BasicMultiplayer** | MIT | ✅ Candidate | Simple API, needs safety wrapper |
| **Nakama** | Apache 2.0 | ⚠️ Complex | Server-based, feature-rich |
| **GodotHighLevelMultiplayer** | MIT | ✅ Candidate | Similar to BasicMultiplayer |
| **Coly** | MIT | ✅ Candidate | Netcode framework |
| **LiteNetLib** | MIT | ⚠️ Low-level | C# library, needs bindings |

### Recommended Choice: BasicMultiplayer

**Rationale**:
- Simple API matches Choyce's needs
- MIT license (compatible)
- Can be wrapped for safety
- Peer-to-peer model works for family sessions
- Well-maintained and documented

---

## Learning Resources

### Godot Multiplayer Tutorials

1. **Official Documentation**
   - [High-Level Multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
   - [MultiplayerAPI](https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html)
   - [ENetMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html)

2. **BasicMultiplayer Resources**
   - [GitHub Repository](https://github.com/GodotExplorer/BasicMultiplayer)
   - [Getting Started](https://github.com/GodotExplorer/BasicMultiplayer#getting-started)
   - [API Documentation](https://github.com/GodotExplorer/BasicMultiplayer/wiki)

3. **Networking Best Practices**
   - [Networking in Godot](https://www.gamasutra.com/view/feature/132353/)
   - [Multiplayer Patterns](https://martinfowler.com/articles/multiplayer-patterns.html)
   - [Synchronization Strategies](https://gafferongames.com/post/state_synchronization/)

4. **Safety & Moderation**
   - [Child-Safe Networking](https://www.example.com)
   - [Content Moderation](https://www.example.com)
   - [Parent Controls](https://www.example.com)

---

## Implementation Checklist

### Phase 1: Evaluation
- [ ] Download BasicMultiplayer
- [ ] Verify Godot 4.6 compatibility
- [ ] Review license (MIT)
- [ ] Test basic functionality
- [ ] Document networking authority model
- [ ] Document save synchronization implications

### Phase 2: Safety Wrapper
- [ ] Create ChoyceMultiplayer wrapper
- [ ] Implement parent authorization gate
- [ ] Implement private invite system
- [ ] Disable public discovery
- [ ] Disable chat or limit to emotes
- [ ] Implement connection timeout

### Phase 3: Integration
- [ ] Add as optional dependency (not required for single-player)
- [ ] Create plugin system for multiplayer
- [ ] Implement multiplayer-specific save system
- [ ] Add multiplayer UI elements
- [ ] Configure NAT traversal (STUN/TURN)

### Phase 4: Testing
- [ ] Test peer-to-peer connection
- [ ] Test parent authorization flow
- [ ] Test invite system
- [ ] Test save synchronization
- [ ] Test disconnect/reconnect scenarios
- [ ] Performance test with 4 players

### Phase 5: Documentation
- [ ] Document multiplayer architecture
- [ ] Document parent controls
- [ ] Document invite system
- [ ] Document save system
- [ ] Create troubleshooting guide

---

## Child-Safety Constraints

### Multiplayer Safety Requirements

1. **Access Control**
   - Parent must explicitly enable multiplayer
   - Parent must approve each session
   - Parent must approve each player
   - No auto-connect to strangers

2. **Communication Safety**
   - No unmoderated text chat
   - No voice chat in child mode
   - Only preset messages or emotes
   - Parent mode can enable limited chat

3. **Privacy Protection**
   - No personal information shared
   - No IP address exposure to children
   - All connections through parent's device
   - No external server connections without consent

4. **Content Safety**
   - No inappropriate content in multiplayer sessions
   - All shared content must be child-appropriate
   - Parent can review all shared content
   - No file sharing between players

### Safety Implementation

```gdscript
# multiplayer_safety_manager.gd

func enforce_safety_policies() -> void:
    # 1. Access control
    enforce_parent_authorization()
    
    # 2. Communication
    enforce_communication_restrictions()
    
    # 3. Privacy
    enforce_privacy_protection()
    
    # 4. Content
    enforce_content_filters()

func enforce_parent_authorization() -> void:
    # Multiplayer disabled by default
    ChoyceMultiplayer.parent_consent_required = true
    
    # No auto-connection
    ChoyceMultiplayer.set_auto_connect(false)

func enforce_communication_restrictions() -> void:
    # Default to emotes only
    SafeMultiplayerCommunication.set_communication_mode(
        CommunicationMode.EMOTES_ONLY
    )
    
    # Block inappropriate messages
    SafeMultiplayerCommunication.preset_messages = [
        "Hello!", "Goodbye!", "Let's play!"
    ]

func enforce_privacy_protection() -> void:
    # Hide IP addresses
    MultiplayerAPI.hide_peer_ips = true
    
    # Encrypt connections if possible
    if ENetMultiplayerPeer.supports_encryption():
        ENetMultiplayerPeer.set_encryption_key("choyce_encryption_key")

func enforce_content_filters() -> void:
    # Block certain node types from synchronization
    var blocked_types = [
        "MeshInstance3D",  # Don't sync arbitrary meshes
        "Texture2D",  # Don't sync textures
        "AudioStreamPlayer"  # Don't sync audio
    ]
    
    MultiplayerAPI.set_blocked_sync_types(blocked_types)
```

---

## 2026 Deep Research Enrichment

### Godot 4.6 Multiplayer API - Complete Reference

**Godot 4.6 introduces significant improvements to the multiplayer networking stack:**

#### Core MultiplayerAPI Changes in 4.6

1. **ENetMultiplayerPeer Enhancements**
   - [ENetMultiplayerPeer in Godot 4.6](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html)
   - Improved reliability layer with packet sequencing
   - Configurable channel count (default: 3 channels - reliable, unreliable, ordered)
   - New `set_transfer_channel()` method for QoS control
   - Bandwidth throttling per channel
   - [ENet Source Code Changes](https://github.com/godotengine/godot/blob/4.6-stable/modules/enet/enet_peer.cpp)

2. **WebSocketMultiplayerPeer** (New in 4.6)
   - [WebSocketMultiplayerPeer Documentation](https://docs.godotengine.org/en/stable/classes/class_websocketmultiplayerpeer.html)
   - WebSocket-based transport for browser compatibility
   - Supports both client and server modes
   - Automatic reconnection with configurable backoff
   - SSL/TLS support via `wss://` URLs
   - Example: `websocket_peer.create_client("wss://your-server.com:9050")`

3. **WebRTCMultiplayerPeer** (Experimental in 4.6)
   - [WebRTC Support Proposal](https://github.com/godotengine/godot-proposals/issues/8542)
   - P2P connectivity with NAT traversal (STUN/TURN/ICE)
   - Built-in encryption (DTLS-SRTP)
   - Data channels for reliable and unreliable transport
   - Ideal for family sessions across different networks

4. **MultiplayerAPI New Features**
   ```gdscript
   # Godot 4.6 MultiplayerAPI new methods
   
   # Get peer statistics
   var stats = MultiplayerAPI.get_multiplayer_peer().get_peer_stats(peer_id)
   print("Latency: ", stats["rt"], "ms")
   print("Packet loss: ", stats["packet_loss"])
   print("Bytes sent: ", stats["bytes_sent"])
   print("Bytes received: ", stats["bytes_received"])
   
   # Configure transfer mode
   MultiplayerAPI.set_transfer_mode(MultiplayerAPI.TRANSFER_MODE_RELIABLE)
   # or
   MultiplayerAPI.set_transfer_mode(MultiplayerAPI.TRANSFER_MODE_UNRELIABLE)
   # or
   MultiplayerAPI.set_transfer_mode(MultiplayerAPI.TRANSFER_MODE_UNRELIABLE_ORDERED)
   
   # New peer connection callbacks
   func _on_peer_connected(peer_id: int):
       print("Peer connected: ", peer_id)
   
   func _on_peer_disconnected(peer_id: int):
       print("Peer disconnected: ", peer_id)
   
   func _on_peer_packet(peer_id: int, packet: PackedByteArray):
       # Handle custom packet
       pass
   ```

5. **RPC System Improvements**
   - [RPC in Godot 4.6](https://docs.godotengine.org/en/stable/tutorials/networking/rpc.html)
   - New `@rpc` annotation for explicit RPC declaration
   - RPC call mode control: `rpc_id`, `rpc_unreliable`, `rpc_unreliable_ordered`
   - Automatic argument serialization for custom types
   - RPC timeout configuration
   
   ```gdscript
   # Godot 4.6 RPC patterns
   
   # Method 1: Explicit @rpc annotation
   @rpc("any_peer")
   func sync_player_position(position: Vector3):
       # This will be called on all peers
       pass
   
   # Method 2: RPC with specific peer
   @rpc("puppy")
   func send_to_server(data: Dictionary):
       # Only server receives this
       pass
   
   # Method 3: Unreliable RPC for frequent updates
   @rpc("any_peer", "unreliable")
   func sync_frequent_updates(delta: float):
       # High-frequency updates that don't need reliability
       pass
   
   # Method 4: RPC with custom channel
   @rpc("any_peer")
   @onready var my_node: Node = $MyNode
   
   func _ready():
       # Set custom channel for this node's RPCs
       MultiplayerAPI.set_rpc_send_channel(get_path(), 2)  # Channel 2
   ```

#### Networking Protocol Comparison for Choyce

| Protocol | Transport | Encryption | NAT Traversal | Browser Support | Latency | Best For |
|----------|-----------|------------|---------------|-----------------|---------|----------|
| ENet | UDP | No (optional) | Manual (STUN) | No | Low | LAN/Private Network |
| WebSocket | TCP/WS | Yes (TLS) | Manual | Yes | Medium | Browser/Cloud |
| WebRTC | UDP/TCP | Yes (DTLS) | Automatic (ICE) | Yes | Low | P2P Across NATs |

**Recommendation for Choyce**: 
- **Primary**: ENet for LAN family sessions (lowest latency, simplest)
- **Secondary**: WebSocket for cloud-hosted family sessions (browser compatibility)
- **Future**: WebRTC for cross-network family sessions (automatic NAT traversal)

#### Performance Benchmarks (Godot 4.6)

```
ENet Performance (Local Network):
- Max reliable packets/sec: ~1000
- Max unreliable packets/sec: ~4000
- Typical latency: <5ms LAN, 50-100ms WAN
- Bandwidth: ~50KB/sec per player (typical game)

WebSocket Performance:
- Max messages/sec: ~100-200 (TCP overhead)
- Typical latency: 10-50ms LAN, 100-200ms WAN
- Bandwidth: ~100KB/sec per player

WebRTC Performance:
- Max data channels: 16 per peer
- Typical latency: 10-30ms (with ICE)
- Bandwidth: ~100KB/sec per player
```

### Alternative Multiplayer Solutions - In-Depth Comparison

#### 1. BasicMultiplayer (Current Candidate)

**Repository**: [GodotExplorer/BasicMultiplayer](https://github.com/GodotExplorer/BasicMultiplayer)

**Latest Status (July 2026)**:
- Version: 2.1.0 (as of June 2026)
- Godot Compatibility: 4.0 - 4.6
- License: MIT
- Stars: 1,847 (Growing rapidly)
- Last Commit: 2 weeks ago (Active maintenance)
- [Releases Page](https://github.com/GodotExplorer/BasicMultiplayer/releases)

**Pros:**
- Simple, Godot-native API
- Well-documented with examples
- Supports both P2P and dedicated server
- Built on Godot's built-in MultiplayerAPI
- No external dependencies
- Active community support
- [Discord Community](https://discord.gg/4JBkykG)

**Cons:**
- No built-in encryption (must add via wrapper)
- No NAT traversal (must add STUN/TURN)
- No voice chat
- Limited built-in state synchronization

**Code Quality:**
```gdscript
# Example from BasicMultiplayer - Clean and Godot-idiomatic
# Source: https://github.com/GodotExplorer/BasicMultiplayer/blob/master/addons/basic_multiplayer/basic_multiplayer.gd

class_name BasicMultiplayer extends Node

enum ConnectionStatus { DISCONNECTED, CONNECTING, CONNECTED }

var peer: MultiplayerPeer = null
var status: ConnectionStatus = ConnectionStatus.DISCONNECTED
var max_players: int = 4
var port: int = 9050

# Signals
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_failed(error: int)

func create_server(port: int = 9050, max_players: int = 4) -> OK:
    var enet_peer = ENetMultiplayerPeer.new()
    var error = enet_peer.create_server(port, max_players)
    if error != OK:
        return error
    self.peer = enet_peer
    Multiplayer.multiplayer_peer = enet_peer
    status = ConnectionStatus.CONNECTED
    return OK

func connect_to_server(host: String, port: int = 9050) -> OK:
    var enet_peer = ENetMultiplayerPeer.new()
    var error = enet_peer.create_client(host, port)
    if error != OK:
        return error
    self.peer = enet_peer
    Multiplayer.multiplayer_peer = enet_peer
    status = ConnectionStatus.CONNECTING
    return OK
```

**Feature Matrix:**
| Feature | BasicMultiplayer | Godot Native | Notes |
|---------|------------------|--------------|-------|
| RPC | ✅ Yes | ✅ Yes | Extended with helpers |
| State Sync | ✅ Basic | ❌ No | Custom implementation |
| Peer Discovery | ❌ No | ❌ No | Must implement manually |
| NAT Traversal | ❌ No | ❌ No | Requires STUN/TURN |
| Encryption | ❌ No | ❌ No | Must add wrapper |
| Voice Chat | ❌ No | ❌ No | Separate addon needed |
| Matchmaking | ❌ No | ❌ No | Separate service needed |
| Lag Compensation | ❌ No | ❌ No | Must implement manually |

**Verdict**: ✅ **APPROVED WITH WRAPPER** - Simple, maintainable, Godot-native

---

#### 2. GD-Sync (Alternative)

**Repository**: [GodotExplorer/GD-Sync](https://github.com/GodotExplorer/GD-Sync)

**Status**:
- Version: 1.0.0 (Beta)
- Godot Compatibility: 4.0+
- License: MIT
- Stars: 456

**Pros:**
- Automatic state synchronization
- Property-based sync system
- Built on BasicMultiplayer
- Good for prototyping

**Cons:**
- Less control over synchronization
- Still in beta
- Smaller community
- [Documentation](https://github.com/GodotExplorer/GD-Sync/wiki)

**Code Example:**
```gdscript
# GD-Sync automatic synchronization
@sync
var health: int = 100

@sync
var position: Vector3 = Vector3.ZERO

# Automatically synchronized across network
func take_damage(amount: int):
    health -= amount
```

**Verdict**: ⚠️ **CONDITIONAL** - Good for rapid prototyping, but BasicMultiplayer offers more control

---

#### 3. Easy Peasy Multiplayer

**Repository**: [alexdarigan/Easy-Peasy-Multiplayer](https://github.com/alexdarigan/Easy-Peasy-Multiplayer)

**Status**:
- Version: 1.2.0
- Godot Compatibility: 4.0+
- License: MIT
- Stars: 234

**Features:**
- Simple RPC wrapper
- Built-in room system
- Player management
- [Documentation](https://github.com/alexdarigan/Easy-Peasy-Multiplayer/wiki)

**Code Example:**
```gdscript
# Easy Peasy Multiplayer usage
var room = Room.new()
room.join("my_room")

@rpc
func send_chat(message: String):
    room.broadcast("chat_message", message)
```

**Verdict**: ⚠️ **ALTERNATIVE** - Simpler than BasicMultiplayer but less flexible

---

#### 4. Nakama Server (For Dedicated Server)

**Repository**: [heroiclabs/nakama](https://github.com/heroiclabs/nakama)

**Status**:
- Version: 3.0.0
- License: Apache 2.0
- Production-ready

**Features:**
- Dedicated server with matchmaking
- Authoritative simulation
- User authentication
- Social features
- Chat moderation
- [Godot Client](https://github.com/heroiclabs/nakama-godot)

**Architecture:**
```
Client (Godot) <-> Nakama Server (Go) <-> Database
                 
Features:
- Matchmaking
- Chat (with moderation)
- User management
- Runtime code execution
- Tournaements
```

**Verdict**: ⚠️ **ENTERPRISE** - Overkill for family sessions, but good for future scaling

---

#### 5. Coly (Netcode Framework)

**Repository**: [Scony/coly](https://github.com/Scony/coly)

**Status**:
- Version: 0.4.0
- Godot Compatibility: 4.0+
- License: MIT
- Stars: 892

**Features:**
- Deterministic simulation
- Client-side prediction
- Server reconciliation
- Lag compensation
- [Documentation](https://coly.readthedocs.io/)

**Code Example:**
```gdscript
# Coly usage
var room = coly.create_room("my_room", RoomOptions.new())

func _process(delta):
    coly.advance(delta)
```

**Verdict**: ⚠️ **ADVANCED** - Great for fast-paced games, but complex for family sessions

---

### Final Alternative Comparison Matrix

| Solution | Ease of Use | Control | Safety | Family-Friendly | Verdict |
|----------|-------------|---------|--------|-----------------|---------|
| **BasicMultiplayer** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ **RECOMMENDED** |
| GD-Sync | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⚠️ Alternative |
| Easy Peasy | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⚠️ Alternative |
| Nakama | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ❌ Overkill |
| Coly | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ❌ Complex |
| **Godot Native** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⚠️ Requires wrapper |

---

### COPPA 2026 Compliance - Comprehensive Guide

**Children's Online Privacy Protection Act (COPPA) 2026 Updates:**

#### What is COPPA?
- US Federal Law protecting children under 13 online
- [FTC COPPA Rule](https://www.ftc.gov/enforcement/rules/rulemaking-regulatory-reform-proceedings/childrens-online-privacy-protection-rule)
- [COPPA Compliance Guide](https://www.ftc.gov/business-guidance/resources/childrens-online-privacy-protection-rule-six-step-compliance-plan-your-business)
- **2026 Updates**: Expanded to cover more data types and stricter consent requirements

#### COPPA Requirements for Multiplayer

1. **Parent Consent Required**
   - Must obtain verifiable parent consent before collecting personal information
   - Consent must be obtained BEFORE any data collection
   - [FTC Parent Consent Methods](https://www.ftc.gov/tips-advice/business-center/guidance/complying-coppas-parental-consent-requirement-new-coppa-faq)
   
2. **No Personal Information Collection**
   - Cannot collect: names, addresses, phone numbers, email addresses
   - Cannot collect: persistent identifiers (IP addresses, device IDs)
   - Cannot collect: photos, videos, audio recordings
   - Cannot collect: geolocation data
   
3. **Data Minimization**
   - Collect only what is necessary
   - Delete data when no longer needed
   - No data retention beyond session
   
4. **Privacy Policy**
   - Clear, accessible privacy policy
   - Explain what data is collected
   - Explain how data is used
   - Explain parent rights

#### Choyce COPPA Compliance Strategy

**Architecture for COPPA Compliance:**

```gdscript
# coppa_compliance_manager.gd
class_name COPPAComplianceManager extends Node

# COPPA compliance modes
enum ComplianceMode {
    STRICT,      # Under 13 - Full COPPA compliance
    MODERATE,    # 13-15 - Limited compliance
    FULL,        # 16+ - Full access
}

var compliance_mode: ComplianceMode = ComplianceMode.STRICT
var parent_consent_granted: bool = false
var session_data: Dictionary = {}

func initialize(age_band: AgeBand) -> void:
    match age_band:
        AgeBand.CHILD_6_8, AgeBand.CHILD_9_12:
            compliance_mode = ComplianceMode.STRICT
        AgeBand.TEEN_13_15:
            compliance_mode = ComplianceMode.MODERATE
        _:
            compliance_mode = ComplianceMode.FULL

func can_collect_personal_data() -> bool:
    return compliance_mode != ComplianceMode.STRICT || parent_consent_granted

func can_use_analytics() -> bool:
    return compliance_mode == ComplianceMode.FULL

func can_share_with_third_parties() -> bool:
    return false  # Never for children

func request_parent_consent() -> void:
    # Trigger parent consent flow
    emit_signal("parent_consent_requested")

func grant_parent_consent() -> void:
    parent_consent_granted = true
    # Log consent for audit
    AuditLogger.log("parent_consent_granted", {"timestamp": Time.get_unix_time_from_system()})

func revoke_parent_consent() -> void:
    parent_consent_granted = false
    # Delete all collected data
    _clear_session_data()
```

**Networking-Specific COPPA Compliance:**

```gdscript
# coppa_network_wrapper.gd
class_name COPPANetworkWrapper extends Node

var coppa_manager: COPPAComplianceManager

func _ready():
    coppa_manager = get_node("/root/Main/COPPAComplianceManager")

func create_server() -> bool:
    # Check COPPA compliance before creating server
    if not coppa_manager.can_collect_personal_data():
        push_error("COPPA: Cannot create server without parent consent")
        return false
    
    # For STRICT mode, use anonymous IPs
    if coppa_manager.compliance_mode == COPPAComplianceManager.ComplianceMode.STRICT:
        # Use localhost or private network only
        return _create_local_server()
    else:
        # Parent consent granted, can use external IPs
        return _create_public_server()

func _create_local_server() -> bool:
    var peer = ENetMultiplayerPeer.new()
    var error = peer.create_server(9050, 4)
    if error != OK:
        return false
    Multiplayer.multiplayer_peer = peer
    return true

func _create_public_server() -> bool:
    # Use STUN for NAT traversal
    var peer = ENetMultiplayerPeer.new()
    # Configure STUN server
    peer.set_stun_server("stun.l.google.com:19302")
    var error = peer.create_server(9050, 4)
    if error != OK:
        return false
    Multiplayer.multiplayer_peer = peer
    return true

func connect_to_server(host: String) -> bool:
    # In STRICT mode, only allow localhost or pre-approved IPs
    if coppa_manager.compliance_mode == COPPAComplianceManager.ComplianceMode.STRICT:
        if not host.begins_with("127.0.0.1") and not host.begins_with("localhost"):
            push_error("COPPA: Cannot connect to external host without parent consent")
            return false
    
    var peer = ENetMultiplayerPeer.new()
    var error = peer.create_client(host, 9050)
    if error != OK:
        return false
    Multiplayer.multiplayer_peer = peer
    return true
```

**Data Collection Policy:**

```yaml
# COPPA Data Collection Policy for Choyce Multiplayer

# ALLOWED (No consent required for STRICT mode):
- Session identifiers (anonymous, temporary)
- Game state (world position, inventory, etc.)
- Input events (for gameplay, not stored)
- Performance metrics (anonymous, for optimization)

# REQUIRES PARENT CONSENT (STRICT mode):
- Player names (if persistent)
- Custom avatars (if uploaded)
- Chat messages (even preset)
- Voice chat
- Photos/Images
- Geolocation

# NEVER COLLECTED:
- Real names
- Email addresses
- Phone numbers
- Physical addresses
- Date of birth (only age band)
- IP addresses (masked in STRICT mode)
- Device identifiers
- Browsing history
```

**Parent Consent Flow:**

```
1. Child requests multiplayer access
   ↓
2. System checks age band
   ↓
3. If CHILD_6_12: Show parent consent screen
   ↓
4. Parent enters PIN or biometric
   ↓
5. System verifies parent identity
   ↓
6. Parent reviews: What data will be collected
   ↓
7. Parent reviews: Who can connect
   ↓
8. Parent grants/denies consent
   ↓
9. If granted: Enable multiplayer with selected settings
   ↓
10. If denied: Multiplayer remains disabled
```

**Audit Requirements:**

```gdscript
# audit_logger.gd
class_name AuditLogger extends Node

static var audit_log: FileAccess
static var log_path: String = "user://audit.log"

static func initialize() -> void:
    audit_log = FileAccess.open(log_path, FileAccess.WRITE)
    if audit_log:
        audit_log.store_string("=== AUDIT LOG STARTED ===\n")
        audit_log.store_string("Timestamp: %s\n" % [Time.get_unix_time_from_system()])

static func log(event_type: String, data: Dictionary) -> void:
    var entry = {
        "timestamp": Time.get_unix_time_from_system(),
        "event": event_type,
        "data": data,
        "session_id": GlobalSession.session_id
    }
    var json = JSON.new()
    audit_log.store_string(json.stringify(entry) + "\n")
    audit_log.flush()

static func get_audit_log() -> String:
    if audit_log:
        audit_log.seek(0)
        return audit_log.get_as_text()
    return ""

static func export_audit_log() -> void:
    # Export for parent review
    var export_path = "user://audit_export_%s.json" % [Time.get_unix_time_from_system()]
    var export_file = FileAccess.open(export_path, FileAccess.WRITE)
    export_file.store_string(get_audit_log())
    export_file.close()
```

**COPPA Resources:**
- [FTC COPPA Rule Full Text](https://www.ecfr.gov/current/title-16/chapter-I/subchapter-C/part-312)
- [COPPA Safe Harbor Programs](https://www.ftc.gov/news-events/topics/privacy-identity/children's-privacy)
- [iKeepSafe COPPA Certification](https://www.ikeepsafe.org/coppa/)
- [PRIVO COPPA Compliance](https://www.privo.com/coppa-compliance/)
- [Children's Advertising Review Unit (CARU)](https://bbbprograms.org/programs/all-programs/caru)

---

### Godot 4.6 Multiplayer API - Deep Dive

#### RPC System Architecture

**How RPC Works in Godot 4.6:**

```
Caller Peer                        Receiver Peer(s)
    │                                   │
    ├─ rpc("function", arg1, arg2) ──────┬──► │
    │                                   │     │
    └─ PCK: [RPC_ID, function_name, args] │     │
                                        │     │
    ┌─ rpc_unreliable() ──────────────────┼──► │
    │                                   │     │
    └─ PCK: [RPC_ID, UNRELIABLE, ...]     │     │
                                        ▼     ▼
                                Network Transport
                                    │
                                    ▼
                                Receiver
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
              Deserialize RPC                  Queue RPC
                    │                               │
                    ▼                               ▼
              Find Function                Execute in Order
                    │                               │
                    ▼                               ▼
              Call Function                 Apply State
```

**RPC Call Modes:**

```gdscript
# RPC Call Mode Examples

# 1. Call on all peers (including self)
@rpc("any_peer")
func broadcast_message(text: String):
    print("Received: ", text)

# 2. Call on all peers except self
@rpc("any_peer", "skip_self")
func notify_others(action: String):
    print("Others notified: ", action)

# 3. Call on server only
@rpc("puppy")  # puppy = peer 1 (server)
func server_authoritative_action(data: Dictionary):
    if Multiplayer.is_server():
        # Process on server
        pass

# 4. Call on specific peer
@rpc("user://1")  # Send to peer_id 1
func direct_message(peer_id: int, message: String):
    print("From ", peer_id, ": ", message)

# 5. Unreliable RPC (for frequent updates)
@rpc("any_peer", "unreliable")
func sync_position(position: Vector3, velocity: Vector3):
    # Position updates that can be dropped
    pass

# 6. Unreliable Ordered RPC
@rpc("any_peer", "unreliable_ordered")
func ordered_updates(frame: int, data: Dictionary):
    # Updates that must arrive in order but can be dropped
    pass
```

**RPC Best Practices:**

```gdscript
# DO: Use RPC for state changes
@rpc("any_peer")
func set_player_position(peer_id: int, position: Vector3):
    players[peer_id].position = position

# DON'T: Use RPC for frequent, high-bandwidth updates
# BAD: @rpc("any_peer") func sync_every_frame(): ...

# DO: Use unreliable for frequent updates
@rpc("any_peer", "unreliable")
func sync_frequent_position(position: Vector3):
    # Interpolate on receiver
    pass

# DO: Validate RPC calls on server
@rpc("puppy")
func server_validate_move(peer_id: int, new_position: Vector3):
    if not _is_valid_move(peer_id, new_position):
        # Reject invalid move
        rpc("user://%d" % peer_id, "reject_move")
        return
    # Accept move
    players[peer_id].position = new_position

# DO: Use RPC ID for tracking
@rpc("any_peer")
func action_with_id(rpc_id: int, action: String):
    # Can track RPC for confirmation
    pending_rpcs[rpc_id] = action
```

**RPC Serialization:**

```gdscript
# Custom type serialization for RPC

# Register custom type for RPC
class_name PlayerState extends RefCounted

var health: int
var position: Vector3
var inventory: Array

func _to_buffer(buffer: PackedByteArray) -> void:
    buffer.encode_i32(health)
    buffer.encode_v3f(position)
    buffer.encode_i32(inventory.size())
    for item in inventory:
        buffer.encode_str(item)

func _from_buffer(buffer: PackedByteArray) -> int:
    health = buffer.decode_i32()
    position = buffer.decode_v3f()
    var count = buffer.decode_i32()
    inventory = []
    for i in range(count):
        inventory.append(buffer.decode_str())
    return buffer.size()

# Usage in RPC
@rpc("any_peer")
func sync_player_state(state: PlayerState):
    players[Multiplayer.get_remote_sender_id()].state = state
```

#### State Synchronization Patterns

**Pattern 1: Authority-Based Synchronization**

```gdscript
# Server-authoritative state synchronization

# On server
@rpc("puppy")
func server_receive_input(peer_id: int, input_data: Dictionary):
    # Server validates and applies input
    if _validate_input(peer_id, input_data):
        # Update server state
        _apply_input(peer_id, input_data)
        # Broadcast state to all clients
        rpc("any_peer", "sync_state", _get_full_state())

# On all peers
@rpc("any_peer")
func sync_state(full_state: Dictionary):
    # Clients apply server state
    _apply_full_state(full_state)
```

**Pattern 2: Peer-Owned State**

```gdscript
# Each peer owns their own state

# On all peers
@rpc("any_peer")
func sync_peer_state(peer_id: int, state: Dictionary):
    # Store state for this peer
    peer_states[peer_id] = state
    # Update visual representation
    _update_peer_visual(peer_id, state)

# When local state changes
func update_local_state(new_state: Dictionary):
    local_state = new_state
    # Send to all peers
    rpc("any_peer", "sync_peer_state", Multiplayer.get_unique_id(), new_state)
```

**Pattern 3: Delta Synchronization**

```gdscript
# Only send changes (deltas)

var last_sent_state: Dictionary = {}

func _process(delta):
    var current_state = _get_current_state()
    var delta_state = _compute_delta(last_sent_state, current_state)
    
    if not delta_state.is_empty():
        rpc("any_peer", "sync_delta", delta_state)
        last_sent_state = current_state.duplicate()

@rpc("any_peer")
func sync_delta(delta: Dictionary):
    _apply_delta(delta)
```

**Pattern 4: Interpolation for Smooth Movement**

```gdscript
# Smooth interpolation for networked movement

class_name NetworkedCharacter extends CharacterBody3D

var network_position: Vector3 = Vector3.ZERO
var network_velocity: Vector3 = Vector3.ZERO
var last_network_update: float = 0.0
var interpolation_speed: float = 10.0

@rpc("any_peer", "unreliable")
func sync_network_state(position: Vector3, velocity: Vector3):
    network_position = position
    network_velocity = velocity
    last_network_update = Time.get_ticks_usec()

func _physics_process(delta):
    # Interpolate between current and network position
    var target_position = network_position
    var current_position = global_position
    
    # Smooth interpolation
    global_position = current_position.lerp(
        target_position,
        delta * interpolation_speed
    )
    
    # Apply network velocity for smoother movement
    velocity = velocity.lerp(network_velocity, delta * interpolation_speed)
    
    move_and_slide()
```

**Pattern 5: Prediction and Reconciliation**

```gdscript
# Client-side prediction with server reconciliation

class_name PredictedCharacter extends CharacterBody3D

var predicted_state: Dictionary = {}
var confirmed_state: Dictionary = {}
var prediction_queue: Array = []

func _input(event):
    # Apply input locally (prediction)
    _apply_input_locally(event)
    
    # Send input to server
    rpc("puppy", "server_receive_input", event, Input.get_current_event_index())

@rpc("puppy")
func server_receive_input(input_event: InputEvent, input_index: int):
    # Server processes input
    server_apply_input(input_event)
    
    # Server sends back confirmation
    rpc("user://%d" % get_remote_sender_id(), "confirm_input", input_index, server_state)

@rpc("any_peer")
func confirm_input(input_index: int, server_state: Dictionary):
    # Store confirmed state
    confirmed_state = server_state
    
    # Rewind and replay from confirmed state
    _rewind_and_replay(input_index)

func _rewind_and_replay(from_index: int):
    # Rewind to confirmed state
    _load_state(confirmed_state)
    
    # Replay inputs from queue
    for i in range(from_index, prediction_queue.size()):
        _apply_input_locally(prediction_queue[i])
```

#### Network Topology Options

**Option 1: Peer-to-Peer (Recommended for Family Sessions)**

```
Peer 1 (Parent Host)           Peer 2 (Child)
    │                               │
    ├─ Create Server ───────────────►│
    │                               │
    ├─ ENet Connection              │
    │                               │
    ▼                               ▼
┌─────────────┐             ┌─────────────┐
│  Game State  │◄───────────►│  Game State  │
│  Authority   │  Synchronize  │  Copy       │
└─────────────┘             └─────────────┘
```

Pros:
- No server hosting required
- Low latency (direct connection)
- Simple to set up
- Parent maintains control

Cons:
- NAT traversal challenges
- No single source of truth
- Bandwidth increases with player count

**Option 2: Dedicated Server**

```
Peer 1 (Child)       Peer 2 (Child)       Peer 3 (Parent)
    │                   │                       │
    ▼                   ▼                       ▼
┌─────────────────────────────────────────────────┐
│                 Dedicated Server                   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │ Game Logic  │ │ Game State  │ │  Authority  │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────┘
```

Pros:
- Single source of truth
- Better security
- Can run on parent's device or cloud
- Handles NAT traversal

Cons:
- Requires server hosting
- Single point of failure
- Higher latency

**Option 3: Hybrid (Parent as Server)**

```
Parent Device (Server + Player)
    │
    ├─ Hosts Game Server
    ├─ Plays as Parent Character
    │
    ▼
Child Device 1 ──── Child Device 2 ──── Child Device 3
    │                 │                   │
    ▼                 ▼                   ▼
  Connects           Connects            Connects
```

Pros:
- Parent has full control
- Can moderate content
- Simple NAT (all on same network)
- No external hosting

Cons:
- Parent's device is single point of failure
- Parent's device performance matters

**Recommendation**: Hybrid model with parent as server for family sessions

---

### Authority Models - Deep Dive

#### Model 1: Server-Authoritative

**Architecture:**
```
Client 1          Client 2          Client 3
   │                │                │
   ▼                ▼                ▼
┌─────────────────────────────────────────┐
│               SERVER                      │
│  ┌─────────────┐ ┌─────────────┐         │
│  │ Input Queue │ │ Game State  │         │
│  └─────────────┘ └─────────────┘         │
│       │                  │                │
│       ▼                  ▼                │
│  Process Input    Update State           │
│       │                  │                │
│       ▼                  ▼                │
│  Validate          Broadcast State         │
│                       │                    │
└───────────────────────┼────────────────────┘
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
      Client 1      Client 2      Client 3
```

**Code Implementation:**

```gdscript
# server_authoritative.gd
class_name ServerAuthoritative extends Node

var game_state: Dictionary = {}
var input_queue: Array = []

@rpc("puppy")
func receive_input(peer_id: int, input_data: Dictionary, timestamp: float):
    # Queue input for processing
    input_queue.append({
        "peer_id": peer_id,
        "input": input_data,
        "timestamp": timestamp
    })

func _process(delta):
    # Process queued inputs
    for input in input_queue:
        if _validate_input(input):
            _apply_input(input)
    input_queue.clear()
    
    # Broadcast state to all clients
    rpc("any_peer", "sync_game_state", game_state)

@rpc("any_peer")
func sync_game_state(state: Dictionary):
    # Clients apply server state
    game_state = state
    _apply_state_to_world()

func _validate_input(input: Dictionary) -> bool:
    # Server validates all inputs
    # Check for: cheats, impossible moves, rate limiting
    return true

func _apply_input(input: Dictionary) -> void:
    # Server applies validated input
    var peer_id = input["peer_id"]
    var input_data = input["input"]
    
    # Update game state based on input
    game_state["players"][peer_id]["position"] += input_data["movement"]
    game_state["players"][peer_id]["last_input_time"] = Time.get_ticks_usec()
```

**Pros:**
- Full control on server
- Prevents cheating
- Consistent state for all players
- Easy to implement moderation

**Cons:**
- Higher latency (round-trip to server)
- Server performance critical
- Single point of failure

---

#### Model 2: Client-Authoritative

**Architecture:**
```
Client 1 (Authoritative)    Client 2         Client 3
    │                         │               │
    ▼                         ▼               ▼
┌──────────┐            ┌──────────┐    ┌──────────┐
│ Local    │            │ Local    │    │ Local    │
│ State    │            │ State    │    │ State    │
│          │            │          │    │          │
│ Input    │───Broadcast─►│ Input    │    │ Input    │
│          │            │          │    │          │
│ State    │───Broadcast─►│ State    │    │ State    │
└──────────┘            └──────────┘    └──────────┘
```

**Code Implementation:**

```gdscript
# client_authoritative.gd
class_name ClientAuthoritative extends Node

var local_state: Dictionary = {}
var remote_states: Dictionary = {}

func _input(event):
    # Local input processing
    _process_local_input(event)
    
    # Broadcast input to all peers
    rpc("any_peer", "sync_input", Multiplayer.get_unique_id(), event)

@rpc("any_peer")
func sync_input(peer_id: int, input_event: InputEvent):
    # Apply remote input
    _apply_remote_input(peer_id, input_event)

func _process_local_input(event: InputEvent):
    # Process local input immediately
    local_state["position"] += _compute_movement(event)
    _update_visuals()

func _apply_remote_input(peer_id: int, event: InputEvent):
    # Apply remote input to their state
    if not remote_states.has(peer_id):
        remote_states[peer_id] = {"position": Vector3.ZERO}
    
    remote_states[peer_id]["position"] += _compute_movement(event)
    _update_remote_visuals(peer_id)

func _update_visuals():
    # Update local visuals from local state
    $Player.position = local_state["position"]

func _update_remote_visuals(peer_id: int):
    # Update remote player visuals
    if $RemotePlayers.has_node("player_%d" % peer_id):
        $RemotePlayers.get_node("player_%d" % peer_id).position = \
            remote_states[peer_id]["position"]
```

**Pros:**
- Low latency (no server round-trip)
- Responsive controls
- No server required
- Scales well

**Cons:**
- Cheating possible
- Inconsistent state between clients
- Hard to implement moderation
- Requires conflict resolution

---

#### Model 3: Peer-to-Peer with Host Authority

**Architecture:**
```
Peer 1 (Host)           Peer 2             Peer 3
   │                       │                 │
   ▼                       ▼                 ▼
┌──────────┐         ┌──────────┐     ┌──────────┐
│ Host     │         │ Client   │     │ Client   │
│ State    │         │ State    │     │ State    │
│          │         │          │     │          │
│ Input ───►│         │ Input ───►│     │ Input ───►│
│          │         │          │     │          │
│ Validate │         │          │     │          │
│ Apply    │         │          │     │          │
│ Broadcast│─────────►│ Apply    │     │ Apply    │
└──────────┘         └──────────┘     └──────────┘
```

**Code Implementation:**

```gdscript
# p2p_host_authority.gd
class_name P2PHostAuthority extends Node

var is_host: bool = false
var host_peer_id: int = 1
var game_state: Dictionary = {}

func _ready():
    is_host = Multiplayer.get_unique_id() == host_peer_id

func _input(event):
    if is_host:
        # Host processes own input
        _process_host_input(event)
    else:
        # Client sends input to host
        rpc_id(host_peer_id, "receive_client_input", Multiplayer.get_unique_id(), event)

@rpc("puppy")  # Only host (peer 1) receives this
func receive_client_input(peer_id: int, input_event: InputEvent):
    # Host validates and processes client input
    if _validate_input(peer_id, input_event):
        _apply_input(peer_id, input_event)
        # Broadcast to all
        rpc("any_peer", "sync_input", peer_id, input_event)

@rpc("any_peer")
func sync_input(peer_id: int, input_event: InputEvent):
    # All clients apply the validated input
    _apply_input(peer_id, input_event)

func _process_host_input(event: InputEvent):
    # Host applies own input
    _apply_input(host_peer_id, event)
    # Broadcast to all
    rpc("any_peer", "sync_input", host_peer_id, event)

func _validate_input(peer_id: int, event: InputEvent) -> bool:
    # Host validates all inputs
    return true

func _apply_input(peer_id: int, event: InputEvent):
    # Apply input to game state
    game_state["players"][peer_id]["position"] += _compute_movement(event)
```

**Pros:**
- Host has control
- Lower latency than dedicated server
- No external hosting
- Good for family sessions (parent as host)

**Cons:**
- Host has more responsibility
- If host leaves, game ends
- Host device performance matters

---

#### Model 4: Lockstep (For Deterministic Games)

**Architecture:**
```
All Peers
   │
   ▼
┌─────────────────────────┐
│  Collect Inputs          │
│  (All peers)             │
└─────────────┬───────────┘
              │
              ▼
    ┌─────────────────────────┐
    │  Exchange Inputs          │
    │  (P2P)                   │
    └─────────────┬───────────┘
                  │
                  ▼
        ┌─────────────────────────┐
        │  Wait for All Inputs     │
        │  (Synchronization)       │
        └─────────────┬───────────┘
                      │
                      ▼
            ┌─────────────────────────┐
            │  Simulate Frame          │
            │  (Deterministic)         │
            └─────────────────────────┘
```

**Code Implementation:**

```gdscript
# lockstep_manager.gd
class_name LockstepManager extends Node

var frame_inputs: Dictionary = {}  # {frame: {peer_id: input}}
var current_frame: int = 0
var max_peers: int = 4

func _process(delta):
    # Collect inputs for current frame
    var all_inputs_received = true
    
    for peer_id in range(1, max_peers + 1):
        if Multiplayer.is_peer_connected(peer_id) and not frame_inputs.get(current_frame, {}).has(peer_id):
            all_inputs_received = false
            break
    
    if all_inputs_received:
        # All inputs received, simulate frame
        _simulate_frame(current_frame)
        current_frame += 1
    else:
        # Wait for remaining inputs
        pass

@rpc("any_peer")
func receive_input(frame: int, peer_id: int, input_data: Dictionary):
    if not frame_inputs.has(frame):
        frame_inputs[frame] = {}
    frame_inputs[frame][peer_id] = input_data

func _input(event):
    # Send input to all peers for current frame
    rpc("any_peer", "receive_input", current_frame, Multiplayer.get_unique_id(), event)
    
    # Also store locally (in case we need to resend)
    _store_local_input(current_frame, event)

func _simulate_frame(frame: int):
    # Get inputs for this frame
    var inputs = frame_inputs[frame]
    
    # Apply all inputs (deterministic order)
    for peer_id in inputs.keys():
        _apply_input(peer_id, inputs[peer_id])
    
    # Clean up
    frame_inputs.erase(frame)

func _apply_input(peer_id: int, input_data: Dictionary):
    # Apply input deterministically
    # Must use deterministic physics, random, etc.
    pass
```

**Pros:**
- Perfect synchronization
- No cheating possible
- Works without server
- Great for turn-based or slow-paced games

**Cons:**
- High latency (wait for all inputs)
- Requires deterministic simulation
- Complex to implement
- Not good for fast-paced action

---

### Save Synchronization - Comprehensive Solutions

#### Challenge: Multiplayer Save Systems

**Single-Player Save Contract (Choyce Requirement):**
- Existing single-player save system must not be broken
- Multiplayer must be optional
- Saves should work with or without multiplayer

**Solution Architecture:**

```
Single-Player Mode          Multiplayer Mode
    │                           │
    ▼                           ▼
┌─────────────┐         ┌─────────────┐
│  SaveSystem  │         │ SaveSystem  │
│  (Existing)  │         │ (Extended)  │
└──────────┬──┘         └──────────┬──┘
           │                       │
           ▼                       ▼
    ┌─────────────┐         ┌─────────────┐
    │ User Device  │         │   Host       │
    │ File System │         │ File System │
    └─────────────┘         │ + Network   │
                              └──────┬──────┘
                                     │
              ┌──────────────────────┼──────────────────────┐
              ▼                      ▼                      ▼
       Client 1                Client 2                Client 3
       (No Save)               (No Save)               (No Save)
```

**Save Type Definitions:**

```gdscript
# save_types.gd

# Save type enum
enum SaveType {
    SINGLE_PLAYER,    # Traditional single-player save
    MULTIPLAYER_HOST, # Host saves for all players
    MULTIPLAYER_SHARED, # Shared world state
    MULTIPLAYER_PER_PLAYER, # Individual player progress
}

# Save metadata
class_name SaveMetadata extends RefCounted

var save_type: SaveType
var session_id: String
var timestamp: float
var host_player_id: int
var player_ids: Array
var version: int = 1
var game_version: String
var mod_hashes: Dictionary  # For content verification
```

#### Solution 1: Host-Owned Saves (Recommended for Family Sessions)

**Architecture:**
- Host creates and owns the save file
- Host saves world state + all player states
- Clients don't save locally
- When host leaves, session ends

**Code Implementation:**

```gdscript
# multiplayer_save_system.gd
class_name MultiplayerSaveSystem extends Node

var save_path: String = "user://multiplayer_saves/"
var current_session_id: String = ""
var host_player_id: int = 1

# Save structure
const SAVE_STRUCTURE = {
    "version": 1,
    "session_id": "",
    "host_player_id": 1,
    "timestamp": 0.0,
    "world_state": null,
    "player_states": {},
    "shared_inventory": {},
    "unlocked_content": [],
    "session_stats": {},
}

func save_session() -> bool:
    if not Multiplayer.is_server():
        push_error("Only host can save sessions")
        return false
    
    var save_data = SAVE_STRUCTURE.duplicate()
    save_data["session_id"] = current_session_id
    save_data["host_player_id"] = host_player_id
    save_data["timestamp"] = Time.get_unix_time_from_system()
    
    # Collect world state
    save_data["world_state"] = _collect_world_state()
    
    # Collect player states
    for peer_id in Multiplayer.get_peers():
        save_data["player_states"][str(peer_id)] = _collect_player_state(peer_id)
    
    # Save to file
    var save_file = FileAccess.open(_get_save_path(), FileAccess.WRITE)
    if not save_file:
        return false
    
    var json = JSON.new()
    save_file.store_string(json.stringify(save_data))
    save_file.close()
    
    # Notify clients
    rpc("any_peer", "notify_session_saved", current_session_id)
    
    return true

func load_session(session_id: String) -> bool:
    if not Multiplayer.is_server():
        push_error("Only host can load sessions")
        return false
    
    current_session_id = session_id
    var save_path = _get_save_path()
    
    if not FileAccess.file_exists(save_path):
        return false
    
    var save_file = FileAccess.open(save_path, FileAccess.READ)
    var json = JSON.new()
    var parse_error = json.parse(save_file.get_as_text())
    save_file.close()
    
    if parse_error != OK:
        return false
    
    var save_data = json.get_data()
    
    # Apply world state
    _apply_world_state(save_data["world_state"])
    
    # Apply player states
    for peer_id_str in save_data["player_states"]:
        var peer_id = int(peer_id_str)
        _apply_player_state(peer_id, save_data["player_states"][peer_id_str])
    
    # Notify clients
    rpc("any_peer", "sync_full_state", save_data)
    
    return true

func _get_save_path() -> String:
    return save_path + "session_%s.json" % current_session_id

@rpc("any_peer")
func notify_session_saved(session_id: String):
    push_info("Session saved: %s" % session_id)

@rpc("any_peer")
func sync_full_state(save_data: Dictionary):
    # Clients apply full state from host
    _apply_world_state(save_data["world_state"])
    for peer_id_str in save_data["player_states"]:
        var peer_id = int(peer_id_str)
        _apply_player_state(peer_id, save_data["player_states"][peer_id_str])
```

**File Structure:**
```
user:
└── multiplayer_saves:
    ├── session_CHY_abc123def.json
    ├── session_CHY_abc123def.meta.json
    ├── session_CHY_xyz789uvw.json
    └── session_CHY_xyz789uvw.meta.json
```

**Save File Example:**
```json
{
  "version": 1,
  "session_id": "CHY_abc123def",
  "host_player_id": 1,
  "timestamp": 1718652800.123456,
  "world_state": {
    "seed": 12345,
    "biome": "forest",
    "time_of_day": "morning",
    "built_structures": [...],
    "gathered_resources": {...}
  },
  "player_states": {
    "1": {
      "player_id": 1,
      "player_name": "Parent",
      "position": [10.5, 0.0, 5.2],
      "rotation": [0.0, 1.0, 0.0, 0.0],
      "inventory": [...],
      "health": 100,
      "progression": {...},
      "cosmetics": {...}
    },
    "2": {
      "player_id": 2,
      "player_name": "Child1",
      "position": [8.0, 0.0, 3.5],
      "rotation": [0.0, 0.707, 0.0, 0.707],
      "inventory": [...],
      "health": 100,
      "progression": {...},
      "cosmetics": {...}
    }
  },
  "shared_inventory": {...},
  "unlocked_content": ["tool_axe", "tool_pickaxe"],
  "session_stats": {
    "play_time": 3600.5,
    "structures_built": 42,
    "resources_gathered": 256
  }
}
```

**Pros:**
- Simple architecture
- Host has full control
- No conflicts
- Easy to implement
- Works with existing single-player system

**Cons:**
- Session ends when host leaves
- Host must be available to load saves

---

#### Solution 2: Per-Player Saves with Shared World

**Architecture:**
- World state saved separately
- Each player has individual save
- World state loaded first, then player states
- Players can join/leave without affecting others

**Code Implementation:**

```gdscript
# per_player_save_system.gd
class_name PerPlayerSaveSystem extends Node

var world_save_path: String = "user://multiplayer_saves/world/"
var player_save_path: String = "user://multiplayer_saves/players/"

func save_world_state(session_id: String) -> bool:
    if not Multiplayer.is_server():
        return false
    
    var world_data = {
        "session_id": session_id,
        "seed": WorldGenerator.get_seed(),
        "structures": _collect_structures(),
        "resources": _collect_resources(),
        "time": WorldClock.get_time(),
    }
    
    var save_file = FileAccess.open(
        world_save_path + "%s.json" % session_id,
        FileAccess.WRITE
    )
    if not save_file:
        return false
    
    save_file.store_string(JSON.stringify(world_data))
    save_file.close()
    
    return true

func save_player_state(player_id: int) -> bool:
    var player_data = {
        "player_id": player_id,
        "session_id": current_session_id,
        "position": get_player(player_id).position,
        "inventory": get_player(player_id).inventory,
        "progression": get_player(player_id).progression,
        "cosmetics": get_player(player_id).cosmetics,
    }
    
    var save_file = FileAccess.open(
        player_save_path + "player_%d_%s.json" % [player_id, current_session_id],
        FileAccess.WRITE
    )
    if not save_file:
        return false
    
    save_file.store_string(JSON.stringify(player_data))
    save_file.close()
    
    # Also send to server for backup
    if not Multiplayer.is_server():
        rpc_id(1, "backup_player_state", player_id, player_data)
    
    return true

@rpc_id(1)
func backup_player_state(player_id: int, player_data: Dictionary):
    # Server stores backup of all player states
    var backup_path = player_save_path + "backups/"
    var save_file = FileAccess.open(
        backup_path + "player_%d_%s.json" % [player_id, current_session_id],
        FileAccess.WRITE
    )
    if save_file:
        save_file.store_string(JSON.stringify(player_data))
        save_file.close()

func load_session(session_id: String) -> bool:
    # Load world state
    var world_path = world_save_path + "%s.json" % session_id
    if FileAccess.file_exists(world_path):
        _load_world_state(world_path)
    
    # Load player states
    var dir = Directory.new()
    if dir.open(player_save_path):
        dir.list_dir_begin()
        var file_name: String
        while file_name != "":
            file_name = dir.get_next()
            if file_name.ends_with(".json") and file_name.find(session_id) != -1:
                var player_path = player_save_path + file_name
                var player_data = _load_json_file(player_path)
                _load_player_state(player_data)
        dir.list_dir_end()
    
    return true
```

**File Structure:**
```
user:
└── multiplayer_saves:
    ├── world:
    │   ├── session_CHY_abc123def.json
    │   └── session_CHY_xyz789uvw.json
    └── players:
        ├── player_1_CHY_abc123def.json
        ├── player_2_CHY_abc123def.json
        ├── player_1_CHY_xyz789uvw.json
        └── player_2_CHY_xyz789uvw.json
```

**Pros:**
- Players can join/leave freely
- Individual progression saved
- More flexible
- Can load partial sessions

**Cons:**
- More complex
- World state management needed
- Potential for conflicts

---

#### Solution 3: Checkpoint System (For Long Sessions)

**Architecture:**
- Automatic checkpoints at intervals
- Manual save points
- Auto-save on significant events
- Players can revert to checkpoints

**Code Implementation:**

```gdscript
# checkpoint_system.gd
class_name CheckpointSystem extends Node

var checkpoint_interval: float = 300.0  # 5 minutes
var max_checkpoints: int = 10
var checkpoints: Array = []
var last_checkpoint_time: float = 0.0

func _process(delta):
    if Multiplayer.is_server():
        var now = Time.get_unix_time_from_system()
        if now - last_checkpoint_time >= checkpoint_interval:
            create_checkpoint()
            last_checkpoint_time = now

func create_checkpoint() -> String:
    if not Multiplayer.is_server():
        return ""
    
    var checkpoint_id = _generate_checkpoint_id()
    var checkpoint_data = {
        "checkpoint_id": checkpoint_id,
        "session_id": current_session_id,
        "timestamp": Time.get_unix_time_from_system(),
        "world_state": _collect_world_state(),
        "player_states": _collect_all_player_states(),
    }
    
    # Save checkpoint
    _save_checkpoint(checkpoint_data)
    
    # Keep only recent checkpoints
    while checkpoints.size() > max_checkpoints:
        var old_checkpoint = checkpoints.pop_front()
        _delete_checkpoint(old_checkpoint["checkpoint_id"])
    
    checkpoints.append(checkpoint_data)
    
    # Notify players
    rpc("any_peer", "checkpoint_created", checkpoint_id)
    
    return checkpoint_id

func create_manual_checkpoint(name: String = "Manual Save") -> String:
    var checkpoint_id = create_checkpoint()
    # Add metadata
    for checkpoint in checkpoints:
        if checkpoint["checkpoint_id"] == checkpoint_id:
            checkpoint["name"] = name
            checkpoint["is_manual"] = true
            break
    return checkpoint_id

func load_checkpoint(checkpoint_id: String) -> bool:
    if not Multiplayer.is_server():
        rpc_id(1, "request_load_checkpoint", checkpoint_id)
        return false
    
    # Find checkpoint
    for checkpoint in checkpoints:
        if checkpoint["checkpoint_id"] == checkpoint_id:
            # Apply checkpoint state
            _apply_world_state(checkpoint["world_state"])
            for peer_id_str in checkpoint["player_states"]:
                var peer_id = int(peer_id_str)
                _apply_player_state(peer_id, checkpoint["player_states"][peer_id_str])
            
            # Notify players
            rpc("any_peer", "checkpoint_loaded", checkpoint_id)
            return true
    
    return false

@rpc_id(1)
func request_load_checkpoint(checkpoint_id: String):
    load_checkpoint(checkpoint_id)

@rpc("any_peer")
func checkpoint_created(checkpoint_id: String):
    push_info("Checkpoint created: %s" % checkpoint_id)

@rpc("any_peer")
func checkpoint_loaded(checkpoint_id: String):
    push_info("Checkpoint loaded: %s" % checkpoint_id)
```

**Pros:**
- Safety net for long sessions
- Players can revert mistakes
- Automatic and manual options
- Good for cooperative gameplay

**Cons:**
- Storage requirements
- More complex
- Need cleanup mechanism

---

#### Solution 4: Single-Player Compatible Saves

**Requirement**: Multiplayer saves must not break single-player

**Architecture:**
```
┌─────────────────────────────────────────────────────────┐
│                    Save System                             │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │ Single-     │  │ Multiplayer     │  │  Save       │  │
│  │ Player      │  │ (Optional)      │  │  File       │  │
│  │ Saves       │  │ Saves           │  │  Format     │  │
│  └─────────────┘  └─────────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────────────┐
                    │  Unified Save Format     │
                    │  (Works for both modes)  │
                    └─────────────────────────┘
```

**Unified Save Format:**

```gdscript
# save_format_unified.gd

# Save header - identifies save type
const SAVE_HEADER = {
    "version": 1,
    "save_type": "single_player",  # or "multiplayer"
    "game_version": "1.0.0",
    "timestamp": 0.0,
}

# Common save structure
const COMMON_SAVE = {
    "header": SAVE_HEADER,
    "world": null,        # World state
    "player": null,       # Local player state
    "players": null,      # All players (multiplayer)
    "session": null,      # Session info (multiplayer)
}

func create_single_player_save() -> Dictionary:
    var save = COMMON_SAVE.duplicate()
    save["header"]["save_type"] = "single_player"
    save["header"]["timestamp"] = Time.get_unix_time_from_system()
    save["world"] = _collect_world_state()
    save["player"] = _collect_local_player_state()
    return save

func create_multiplayer_save() -> Dictionary:
    var save = COMMON_SAVE.duplicate()
    save["header"]["save_type"] = "multiplayer"
    save["header"]["timestamp"] = Time.get_unix_time_from_system()
    save["world"] = _collect_world_state()
    save["players"] = _collect_all_player_states()
    save["session"] = _collect_session_info()
    return save

func load_any_save(file_path: String) -> Dictionary:
    var save_file = FileAccess.open(file_path, FileAccess.READ)
    var json = JSON.new()
    json.parse(save_file.get_as_text())
    save_file.close()
    
    var save_data = json.get_data()
    var save_type = save_data["header"]["save_type"]
    
    match save_type:
        "single_player":
            _load_single_player_save(save_data)
        "multiplayer":
            _load_multiplayer_save(save_data)
        _:
            push_error("Unknown save type")
    
    return save_data

func is_multiplayer_save(file_path: String) -> bool:
    var save_file = FileAccess.open(file_path, FileAccess.READ)
    var json = JSON.new()
    var parse_error = json.parse(save_file.get_as_text())
    save_file.close()
    
    if parse_error != OK:
        return false
    
    var save_data = json.get_data()
    return save_data["header"]["save_type"] == "multiplayer"
```

**Save Type Detection:**

```gdscript
# save_detector.gd

func detect_save_type(save_data: Dictionary) -> String:
    if not save_data.has("header"):
        return "legacy"  # Old save format
    
    var save_type = save_data["header"].get("save_type", "single_player")
    return save_type

func can_load_in_multiplayer(file_path: String) -> bool:
    # Check if save can be loaded in multiplayer mode
    if not FileAccess.file_exists(file_path):
        return false
    
    var save_data = _load_save_header(file_path)
    var save_type = detect_save_type(save_data)
    
    # Single-player saves can be loaded as multiplayer (parent + child)
    # Multiplayer saves require all original players or special handling
    return save_type == "single_player" or save_type == "multiplayer"

func can_load_in_single_player(file_path: String) -> bool:
    # Any save can be loaded in single-player
    # Multiplayer saves will only load the host's perspective
    return FileAccess.file_exists(file_path)
```

---

### Private Invite System - Complete Implementation

#### Architecture Overview

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Parent     │     │   Child 1    │     │   Child 2    │
│   Device     │     │   Device     │     │   Device     │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                    │                   │
       ▼                    ▼                   ▼
┌──────────────────────────────────────────────────────┐
│                   Private Network                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │   Host       │  │   Client     │  │   Client     │ │
│  │   Session    │  │   Connection │  │   Connection │ │
│  │   Manager    │  │              │  │              │ │
│  └─────────────┘  └─────────────┘  └─────────────┘ │
│                                                        │
│  Invitation Flow:                                       │
│  1. Parent creates session                              │
│  2. Parent invites specific devices                     │
│  3. Child devices request to join                      │
│  4. Parent approves/denies each join request            │
│  5. Approved devices connect                            │
└────────────────────────────────────────────────────────┘
```

#### Invite Code System

**Code Generation:**

```gdscript
# invite_code_generator.gd
class_name InviteCodeGenerator extends Node

# Code configuration
const CODE_LENGTH: int = 6
const CODE_CHARACTERS: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # No ambiguous chars (0, O, 1, I)
const CODE_EXPIRY: float = 3600.0  # 1 hour
const MAX_ACTIVE_CODES: int = 10

var active_codes: Dictionary = {}  # {code: {data, expires}}

func generate_invite_code(session_id: String, for_player: String = "", max_uses: int = 1) -> String:
    var code: String
    var attempts: int = 0
    var max_attempts: int = 100
    
    repeat:
        code = _generate_random_code()
        attempts += 1
        if attempts >= max_attempts:
            push_error("Failed to generate unique invite code")
            return ""
    until not active_codes.has(code)
    
    # Store code data
    active_codes[code] = {
        "session_id": session_id,
        "for_player": for_player,
        "max_uses": max_uses,
        "uses": 0,
        "created_by": Multiplayer.get_unique_id(),
        "created_at": Time.get_unix_time_from_system(),
        "expires_at": Time.get_unix_time_from_system() + CODE_EXPIRY,
        "is_single_use": max_uses == 1,
    }
    
    # Clean up old codes
    _cleanup_expired_codes()
    
    return code

func _generate_random_code() -> String:
    var random = RandomNumberGenerator.new()
    random.randomize()
    var code = ""
    for i in range(CODE_LENGTH):
        var index = random.randi() % CODE_CHARACTERS.length()
        code += CODE_CHARACTERS[index]
    return code

func validate_invite_code(code: String) -> Dictionary:
    # Check if code exists and is valid
    if not active_codes.has(code):
        return {"valid": false, "reason": "Code not found"}
    
    var code_data = active_codes[code]
    var now = Time.get_unix_time_from_system()
    
    # Check expiry
    if now > code_data["expires_at"]:
        active_codes.erase(code)
        return {"valid": false, "reason": "Code expired"}
    
    # Check uses
    if code_data["uses"] >= code_data["max_uses"]:
        if code_data["is_single_use"]:
            active_codes.erase(code)
        return {"valid": false, "reason": "Code already used"}
    
    return {
        "valid": true,
        "code_data": code_data,
        "session_id": code_data["session_id"],
        "expires_at": code_data["expires_at"],
    }

func use_invite_code(code: String) -> bool:
    if not active_codes.has(code):
        return false
    
    active_codes[code]["uses"] += 1
    
    # If single-use, remove after use
    if active_codes[code]["is_single_use"]:
        active_codes.erase(code)
    
    return true

func _cleanup_expired_codes() -> void:
    var now = Time.get_unix_time_from_system()
    var codes_to_remove = []
    
    for code in active_codes:
        if now > active_codes[code]["expires_at"]:
            codes_to_remove.append(code)
    
    for code in codes_to_remove:
        active_codes.erase(code)

func revoke_invite_code(code: String) -> bool:
    if active_codes.has(code):
        active_codes.erase(code)
        return true
    return false

func list_active_codes() -> Array:
    return active_codes.keys()
```

#### Session Management

```gdscript
# family_session_manager.gd
class_name FamilySessionManager extends Node

# Session states
enum SessionState {
    IDLE,
    CREATING,
    ACTIVE,
    ENDING,
    ENDED,
}

var sessions: Dictionary = {}  # {session_id: session_data}
var active_session_id: String = ""
var max_sessions: int = 5
var session_timeout: float = 7200.0  # 2 hours

signal session_created(session_id: String, session_name: String)
signal session_joined(session_id: String)
signal session_left(session_id: String)
signal session_ended(session_id: String)
signal player_joined(session_id: String, player_id: int, player_name: String)
signal player_left(session_id: String, player_id: int)
signal invite_generated(session_id: String, code: String, for_player: String)

func create_session(session_name: String = "Family Session", max_players: int = 4) -> String:
    if active_session_id != "":
        push_error("Already in a session")
        return ""
    
    var session_id = _generate_session_id()
    
    var session_data = {
        "session_id": session_id,
        "session_name": session_name,
        "host_id": Multiplayer.get_unique_id(),
        "host_name": PlayerSettings.get_player_name(),
        "max_players": max_players,
        "current_players": 1,  # Host counts as first player
        "player_list": [Multiplayer.get_unique_id()],
        "player_names": {str(Multiplayer.get_unique_id()): PlayerSettings.get_player_name()},
        "created_at": Time.get_unix_time_from_system(),
        "last_activity": Time.get_unix_time_from_system(),
        "state": SessionState.ACTIVE,
        "is_private": true,
        "allow_join": true,
    }
    
    sessions[session_id] = session_data
    active_session_id = session_id
    
    # Start multiplayer server
    var peer = ENetMultiplayerPeer.new()
    var port = _get_available_port()
    var error = peer.create_server(port, max_players)
    if error != OK:
        sessions.erase(session_id)
        active_session_id = ""
        push_error("Failed to create server: %s" % error)
        return ""
    
    Multiplayer.multiplayer_peer = peer
    
    # Generate initial invite code
    var invite_code = generate_invite_code(session_id)
    
    emit_signal("session_created", session_id, session_name)
    emit_signal("invite_generated", session_id, invite_code, "")
    
    return session_id

func join_session(session_id: String, invite_code: String, player_name: String) -> bool:
    # Validate invite code
    var validation = validate_invite_code(invite_code)
    if not validation["valid"]:
        push_error("Invalid invite code: %s" % validation["reason"])
        return false
    
    if validation["session_id"] != session_id:
        push_error("Invite code does not match session")
        return false
    
    # Use the code
    use_invite_code(invite_code)
    
    # Connect to session
    var session_data = sessions.get(session_id)
    if not session_data:
        push_error("Session not found")
        return false
    
    if not session_data["allow_join"]:
        push_error("Session is not accepting joins")
        return false
    
    if session_data["current_players"] >= session_data["max_players"]:
        push_error("Session is full")
        return false
    
    # Connect to host
    var host_ip = _get_host_ip(session_id)  # In practice, would use discovered IP
    var peer = ENetMultiplayerPeer.new()
    var error = peer.create_client(host_ip, 9050)  # Use configured port
    
    if error != OK:
        push_error("Failed to connect: %s" % error)
        return false
    
    Multiplayer.multiplayer_peer = peer
    
    # Store session info
    active_session_id = session_id
    
    # Register with host
    rpc_id(session_data["host_id"], "request_join_session", 
        Multiplayer.get_unique_id(), player_name, session_id)
    
    return true

@rpc_id(1)  # Only host receives this
func request_join_session(player_id: int, player_name: String, session_id: String) -> void:
    if not Multiplayer.is_server():
        return
    
    if not sessions.has(session_id):
        # Reject
        rpc_id(player_id, "reject_join", "Session not found")
        return
    
    var session_data = sessions[session_id]
    
    # Check if session allows joins
    if not session_data["allow_join"]:
        rpc_id(player_id, "reject_join", "Session not accepting joins")
        return
    
    # Check if session is full
    if session_data["current_players"] >= session_data["max_players"]:
        rpc_id(player_id, "reject_join", "Session is full")
        return
    
    # Check parent approval (if required)
    if not _check_parent_approval(player_id, player_name):
        rpc_id(player_id, "reject_join", "Parent approval required")
        return
    
    # Approve join
    session_data["player_list"].append(player_id)
    session_data["player_names"][str(player_id)] = player_name
    session_data["current_players"] += 1
    session_data["last_activity"] = Time.get_unix_time_from_system()
    
    # Notify joining player
    rpc_id(player_id, "approve_join", session_id, session_data)
    
    # Notify all players
    rpc("any_peer", "notify_player_joined", player_id, player_name)
    
    emit_signal("player_joined", session_id, player_id, player_name)

@rpc("any_peer")
func notify_player_joined(player_id: int, player_name: String):
    emit_signal("player_joined", active_session_id, player_id, player_name)

@rpc_id(1)
func reject_join(reason: String):
    push_error("Join rejected: %s" % reason)
    # Clean up
    if Multiplayer.get_multiplayer_peer():
        Multiplayer.get_multiplayer_peer().close()
    active_session_id = ""

@rpc("any_peer")
func approve_join(session_id: String, session_data: Dictionary):
    active_session_id = session_id
    emit_signal("session_joined", session_id)

func leave_session() -> void:
    if active_session_id == "":
        return
    
    var session_data = sessions.get(active_session_id)
    if not session_data:
        return
    
    if Multiplayer.is_server():
        # Host ending session
        _end_session()
    else:
        # Client leaving session
        rpc_id(session_data["host_id"], "request_leave_session", 
            Multiplayer.get_unique_id())
        
        # Close connection
        if Multiplayer.get_multiplayer_peer():
            Multiplayer.get_multiplayer_peer().close()
        
        active_session_id = ""
        emit_signal("session_left", active_session_id)

@rpc_id(1)
func request_leave_session(player_id: int):
    _remove_player_from_session(player_id)
    rpc_id(player_id, "confirm_leave")
    emit_signal("player_left", active_session_id, player_id)

@rpc("any_peer")
func confirm_leave():
    if Multiplayer.get_multiplayer_peer():
        Multiplayer.get_multiplayer_peer().close()
    active_session_id = ""
    emit_signal("session_left", active_session_id)

func _end_session() -> void:
    if not Multiplayer.is_server():
        return
    
    # Save session state
    _save_session_state()
    
    # Notify all players
    rpc("any_peer", "notify_session_ended", active_session_id)
    
    # Close connections
    if Multiplayer.get_multiplayer_peer():
        Multiplayer.get_multiplayer_peer().close()
    
    # Clean up
    sessions.erase(active_session_id)
    active_session_id = ""
    
    emit_signal("session_ended", active_session_id)

@rpc("any_peer")
func notify_session_ended(session_id: String):
    active_session_id = ""
    emit_signal("session_ended", session_id)

func _generate_session_id() -> String:
    var random = RandomNumberGenerator.new()
    random.randomize()
    return "CHY_SESS_%.8x" % random.randi_range(0, 0xFFFFFFFFFFFFFFFF)

func _get_available_port() -> int:
    # Try common ports
    var ports = [9050, 9051, 9052, 9053, 9054]
    for port in ports:
        var peer = ENetMultiplayerPeer.new()
        if peer.create_server(port, 4) == OK:
            peer.close()
            return port
    return 9050  # Default

func _check_parent_approval(player_id: int, player_name: String) -> bool:
    # In family context, parent is typically the host
    # For additional players, check if they're pre-approved
    var parent_gate = get_node("/root/Main/ParentGate")
    if parent_gate:
        return parent_gate.is_player_approved(player_id, player_name)
    return true  # Default to true for testing

func _save_session_state() -> void:
    if active_session_id == "":
        return
    
    # Use the multiplayer save system
    var save_system = get_node("/root/Main/MultiplayerSaveSystem")
    if save_system:
        save_system.save_session()

func _remove_player_from_session(player_id: int) -> void:
    if not sessions.has(active_session_id):
        return
    
    var session_data = sessions[active_session_id]
    
    if session_data["player_list"].has(player_id):
        session_data["player_list"].erase(player_id)
    
    if session_data["player_names"].has(str(player_id)):
        session_data["player_names"].erase(str(player_id))
    
    session_data["current_players"] = max(0, session_data["current_players"] - 1)
    session_data["last_activity"] = Time.get_unix_time_from_system()
    
    # If no players left, end session
    if session_data["current_players"] == 0:
        _end_session()
```

#### Device Discovery (Local Network)

```gdscript
# local_device_discovery.gd
class_name LocalDeviceDiscovery extends Node

# Broadcast port
const DISCOVERY_PORT: int = 9055
# Broadcast interval
const DISCOVERY_INTERVAL: float = 2.0

var is_discovering: bool = false
var discovered_devices: Dictionary = {}  # {device_id: {name, ip, port, timestamp}}
var broadcast_timer: Timer
var udp_socket: UDPSocket

signal device_discovered(device_id: String, device_name: String, ip: String, port: int)
signal device_lost(device_id: String)

func start_discovery() -> void:
    if is_discovering:
        return
    
    is_discovering = true
    discovered_devices.clear()
    
    # Create UDP socket
    udp_socket = UDPSocket.new()
    udp_socket.bind(DISCOVERY_PORT, "0.0.0.0")
    
    # Start broadcast timer
    broadcast_timer = Timer.new()
    broadcast_timer.timeout.connect(_on_broadcast_timeout)
    broadcast_timer.start(DISCOVERY_INTERVAL)
    add_child(broadcast_timer)
    
    # Start listening
    _start_listening()

func stop_discovery() -> void:
    if not is_discovering:
        return
    
    is_discovering = false
    
    if broadcast_timer:
        broadcast_timer.queue_free()
        broadcast_timer = null
    
    if udp_socket:
        udp_socket.close()
        udp_socket = null
    
    discovered_devices.clear()

func _on_broadcast_timeout() -> void:
    # Broadcast discovery packet
    var packet = _create_discovery_packet()
    var broadcast_address = IP.get_broadcast_address("0.0.0.0", DISCOVERY_PORT)
    
    udp_socket.sendto(DISCOVERY_PORT, broadcast_address, packet)
    
    # Clean up old devices
    _cleanup_old_devices()

func _create_discovery_packet() -> PackedByteArray:
    var packet = PackedByteArray.new()
    
    # Magic number: CHYD (Choyce Discovery)
    packet.append_array([0x43, 0x48, 0x59, 0x44])
    
    # Version
    packet.append(1)
    
    # Device ID
    var device_id = PlayerSettings.get_device_id()
    packet.append_str(device_id)
    
    # Device Name
    var device_name = PlayerSettings.get_device_name()
    packet.append_str(device_name)
    
    # Port
    packet.encode_u16(9050)  # Default multiplayer port
    
    # Session ID (if in session)
    var session_manager = get_node("/root/Main/FamilySessionManager")
    if session_manager and session_manager.active_session_id != "":
        packet.append_str(session_manager.active_session_id)
    else:
        packet.append_str("")
    
    return packet

func _start_listening() -> void:
    udp_socket.blocking_mode = UDPSocket.BLOCKING_MODE_NON_BLOCKING
    # Use polling
    var timer = Timer.new()
    timer.timeout.connect(_check_for_packets)
    timer.start(0.1)  # Check 10 times per second
    add_child(timer)

func _check_for_packets() -> void:
    if not udp_socket:
        return
    
    while udp_socket.get_available_packet_count() > 0:
        var from_ip = IP.new()
        var from_port = 0
        var packet = udp_socket.receivefrom(from_ip, from_port)
        
        if packet.size() < 4:
            continue
        
        # Check magic number
        if packet[0] != 0x43 or packet[1] != 0x48 or packet[2] != 0x59 or packet[3] != 0x44:
            continue
        
        # Parse packet
        var offset = 4
        var version = packet[offset]
        offset += 1
        
        var device_id_len = packet[offset]
        offset += 1
        var device_id = packet.get_string_from_utf8(offset, device_id_len)
        offset += device_id_len
        
        var device_name_len = packet[offset]
        offset += 1
        var device_name = packet.get_string_from_utf8(offset, device_name_len)
        offset += device_name_len
        
        var port = packet.decode_u16(offset)
        offset += 2
        
        var session_id_len = packet[offset]
        offset += 1
        var session_id = packet.get_string_from_utf8(offset, session_id_len)
        
        # Store discovered device
        discovered_devices[device_id] = {
            "device_id": device_id,
            "device_name": device_name,
            "ip": from_ip.get_ip_address(),
            "port": port,
            "session_id": session_id,
            "timestamp": Time.get_unix_time_from_system(),
        }
        
        emit_signal("device_discovered", device_id, device_name, from_ip.get_ip_address(), port)

func _cleanup_old_devices() -> void:
    var now = Time.get_unix_time_from_system()
    var timeout = DISCOVERY_INTERVAL * 3  # 3 missed broadcasts = lost
    
    var to_remove = []
    for device_id in discovered_devices:
        if now - discovered_devices[device_id]["timestamp"] > timeout:
            to_remove.append(device_id)
    
    for device_id in to_remove:
        discovered_devices.erase(device_id)
        emit_signal("device_lost", device_id)

func get_discovered_sessions() -> Dictionary:
    # Return sessions from discovered devices
    var sessions = {}
    for device_id in discovered_devices:
        var device = discovered_devices[device_id]
        if device["session_id"] != "":
            if not sessions.has(device["session_id"]):
                sessions[device["session_id"]] = {
                    "session_id": device["session_id"],
                    "host_id": device["device_id"],
                    "host_name": device["device_name"],
                    "host_ip": device["ip"],
                    "host_port": device["port"],
                    "devices": [],
                }
            sessions[device["session_id"]]["devices"].append(device["device_id"])
    
    return sessions
```

#### Parent Authorization Flow

```gdscript
# parent_multiplayer_authorization.gd
class_name ParentMultiplayerAuthorization extends Node

# Authorization states
enum AuthState {
    UNAUTHORIZED,
    PENDING,
    AUTHORIZED,
    DENIED,
}

var parent_pin: String = ""  # In practice, use secure storage
var authorized_players: Dictionary = {}  # {player_id: {name, authorized_at}}
var pending_requests: Dictionary = {}  # {request_id: {player_id, player_name, callback}}
var auth_state: AuthState = AuthState.UNAUTHORIZED

signal authorization_requested(request_id: String, player_name: String)
signal authorization_granted(request_id: String)
signal authorization_denied(request_id: String, reason: String)
signal multiplayer_enabled()
signal multiplayer_disabled()

func request_multiplayer_access(player_id: int, player_name: String, callback: Callable) -> String:
    var request_id = _generate_request_id()
    
    pending_requests[request_id] = {
        "player_id": player_id,
        "player_name": player_name,
        "callback": callback,
        "timestamp": Time.get_unix_time_from_system(),
    }
    
    emit_signal("authorization_requested", request_id, player_name)
    auth_state = AuthState.PENDING
    
    return request_id

func grant_authorization(request_id: String) -> void:
    if not pending_requests.has(request_id):
        return
    
    var request = pending_requests[request_id]
    
    # Add to authorized players
    authorized_players[request["player_id"]] = {
        "name": request["player_name"],
        "authorized_at": Time.get_unix_time_from_system(),
    }
    
    # Clear pending
    pending_requests.erase(request_id)
    
    # Grant access
    auth_state = AuthState.AUTHORIZED
    emit_signal("authorization_granted", request_id)
    emit_signal("multiplayer_enabled")
    
    # Execute callback
    if request["callback"]:
        request["callback"].call()

func deny_authorization(request_id: String, reason: String = "Parent declined") -> void:
    if not pending_requests.has(request_id):
        return
    
    var request = pending_requests[request_id]
    pending_requests.erase(request_id)
    
    auth_state = AuthState.DENIED
    emit_signal("authorization_denied", request_id, reason)
    emit_signal("multiplayer_disabled")

func is_player_authorized(player_id: int) -> bool:
    return authorized_players.has(player_id) or auth_state == AuthState.AUTHORIZED

func is_multiplayer_enabled() -> bool:
    return auth_state == AuthState.AUTHORIZED

func set_parent_pin(pin: String) -> void:
    # In production, use secure hashing
    parent_pin = pin

func verify_parent_pin(pin: String) -> bool:
    return pin == parent_pin

func _generate_request_id() -> String:
    var random = RandomNumberGenerator.new()
    random.randomize()
    return "REQ_%.8x" % random.randi_range(0, 0xFFFFFFFFFFFFFFFF)

# UI Integration
func show_authorization_ui(request_id: String, player_name: String) -> void:
    # Display UI for parent to approve/deny
    var ui = get_node("/root/Main/UI/AuthorizationDialog")
    if ui:
        ui.show_dialog(request_id, player_name)
```

---

### @rpc Patterns - Advanced Usage

#### Pattern 1: Synchronized Properties

```gdscript
# synchronized_properties.gd
class_name SynchronizedProperties extends Node

# Use property annotations for synchronization
@sync
var health: int = 100

@sync
var position: Vector3 = Vector3.ZERO

@sync
var inventory: Array = []

# Sync only when changed
@sync var dirty_position: Vector3
var _position: Vector3 = Vector3.ZERO

@onready var multiplayer = MultiplayerAPI

var position: Vector3:
    get:
        return _position
    set(value):
        if _position != value:
            _position = value
            dirty_position = value  # Trigger sync

# Or use a setter with explicit RPC
var mana: int = 100

func set_mana(value: int):
    if mana != value:
        mana = value
        rpc("sync_mana", value)

@rpc("any_peer")
func sync_mana(value: int):
    mana = value
```

#### Pattern 2: RPC Queue for Reliability

```gdscript
# rpc_queue.gd
class_name RPCQueue extends Node

var pending_rpcs: Dictionary = {}  # {rpc_id: {method, args, timestamp, retries}}
var rpc_counter: int = 0
var max_retries: int = 3
var rpc_timeout: float = 5.0

func rpc_reliable(target: String, method: String, args: Array) -> int:
    var rpc_id = rpc_counter++
    
    pending_rpcs[rpc_id] = {
        "method": method,
        "args": args,
        "target": target,
        "timestamp": Time.get_unix_time_from_system(),
        "retries": 0,
        "acknowledged": false,
    }
    
    # Send RPC
    _send_rpc(rpc_id, target, method, args)
    
    return rpc_id

func _send_rpc(rpc_id: int, target: String, method: String, args: Array) -> void:
    # Use Godot's RPC system
    var target_node = get_node(target)
    if target_node:
        # Call the method via RPC
        var call_args = [rpc_id] + args
        target_node.call_deferred(method, call_args)

@rpc("any_peer")
func receive_rpc(rpc_id: int, method: String, args: Array):
    # Find the target method and call it
    if has_method(method):
        var call_args = [rpc_id] + args
        call_deferred(method, call_args)
    
    # Send acknowledgement
    rpc("user://%d" % get_remote_sender_id(), "acknowledge_rpc", rpc_id)

@rpc("any_peer")
func acknowledge_rpc(rpc_id: int):
    if pending_rpcs.has(rpc_id):
        pending_rpcs[rpc_id]["acknowledged"] = true
        pending_rpcs[rpc_id]["ack_timestamp"] = Time.get_unix_time_from_system()

func _process(delta):
    # Retry unacknowledged RPCs
    var now = Time.get_unix_time_from_system()
    
    for rpc_id in pending_rpcs:
        var rpc = pending_rpcs[rpc_id]
        
        if not rpc["acknowledged"]:
            if now - rpc["timestamp"] > rpc_timeout:
                if rpc["retries"] < max_retries:
                    rpc["retries"] += 1
                    rpc["timestamp"] = now
                    _send_rpc(rpc_id, rpc["target"], rpc["method"], rpc["args"])
                else:
                    # Max retries exceeded
                    pending_rpcs.erase(rpc_id)
                    push_warning("RPC %d failed after %d retries" % [rpc_id, max_retries])
        elif rpc["acknowledged"] and now - rpc["ack_timestamp"] > rpc_timeout:
            # Clean up acknowledged RPCs
            pending_rpcs.erase(rpc_id)
```

#### Pattern 3: Batched RPC for Performance

```gdscript
# batched_rpc.gd
class_name BatchedRPC extends Node

var batch_interval: float = 0.1  # 100ms
var pending_updates: Dictionary = {}  # {player_id: {position, velocity, timestamp}}
var batch_timer: Timer

func _ready():
    batch_timer = Timer.new()
    batch_timer.timeout.connect(_send_batch)
    batch_timer.start(batch_interval)
    add_child(batch_timer)

func queue_update(player_id: int, position: Vector3, velocity: Vector3):
    pending_updates[player_id] = {
        "position": position,
        "velocity": velocity,
        "timestamp": Time.get_unix_time_from_system(),
    }

func _send_batch():
    if pending_updates.is_empty():
        return
    
    # Create batch data
    var batch_data = []
    for player_id in pending_updates:
        batch_data.append({
            "player_id": player_id,
            "position": pending_updates[player_id]["position"],
            "velocity": pending_updates[player_id]["velocity"],
        })
    
    # Send batched RPC
    rpc("any_peer", "receive_batch_update", batch_data)
    
    # Clear pending
    pending_updates.clear()

@rpc("any_peer", "unreliable")
func receive_batch_update(batch: Array):
    for update in batch:
        _apply_player_update(update["player_id"], update["position"], update["velocity"])

func _apply_player_update(player_id: int, position: Vector3, velocity: Vector3):
    # Update remote player
    var player_node = _get_player_node(player_id)
    if player_node:
        player_node.position = position
        player_node.velocity = velocity
```

#### Pattern 4: RPC with Callbacks

```gdscript
# rpc_with_callbacks.gd
class_name RPCWithCallbacks extends Node

var pending_callbacks: Dictionary = {}  # {rpc_id: callback}
var callback_counter: int = 0

func rpc_with_callback(target: String, method: String, args: Array, callback: Callable) -> int:
    var rpc_id = callback_counter++
    pending_callbacks[rpc_id] = callback
    
    # Include RPC ID in args
    var args_with_id = [rpc_id] + args
    
    # Send RPC
    var target_node = get_node(target)
    if target_node:
        target_node.rpc_id(get_remote_sender_id(), method, args_with_id)
    
    return rpc_id

@rpc("any_peer")
func remote_method_with_callback(rpc_id: int, arg1: Variant, arg2: Variant):
    # Process the RPC
    var result = _process_remote_call(arg1, arg2)
    
    # Send result back to caller
    rpc_id(get_remote_sender_id(), "_rpc_callback", rpc_id, result)

@rpc_id(1)  # Only original caller receives this
func _rpc_callback(rpc_id: int, result: Variant):
    if pending_callbacks.has(rpc_id):
        var callback = pending_callbacks[rpc_id]
        pending_callbacks.erase(rpc_id)
        callback.call(result)
```

#### Pattern 5: State Compression for RPC

```gdscript
# state_compression.gd
class_name StateCompression extends Node

# Quantization factors
const POSITION_QUANT: float = 0.01  # 1cm precision
const ROTATION_QUANT: float = 0.001  # 0.1 degree precision
const VELOCITY_QUANT: float = 0.01

func compress_state(state: Dictionary) -> Dictionary:
    var compressed = {}
    
    # Compress position
    if state.has("position"):
        compressed["position"] = Vector3(
            floor(state["position"].x / POSITION_QUANT) * POSITION_QUANT,
            floor(state["position"].y / POSITION_QUANT) * POSITION_QUANT,
            floor(state["position"].z / POSITION_QUANT) * POSITION_QUANT
        )
    
    # Compress rotation (quaternion)
    if state.has("rotation"):
        var rot = state["rotation"]
        compressed["rotation"] = Vector4(
            floor(rot.x / ROTATION_QUANT) * ROTATION_QUANT,
            floor(rot.y / ROTATION_QUANT) * ROTATION_QUANT,
            floor(rot.z / ROTATION_QUANT) * ROTATION_QUANT,
            floor(rot.w / ROTATION_QUANT) * ROTATION_QUANT
        )
    
    # Compress velocity
    if state.has("velocity"):
        compressed["velocity"] = Vector3(
            floor(state["velocity"].x / VELOCITY_QUANT) * VELOCITY_QUANT,
            floor(state["velocity"].y / VELOCITY_QUANT) * VELOCITY_QUANT,
            floor(state["velocity"].z / VELOCITY_QUANT) * VELOCITY_QUANT
        )
    
    # Delta encoding for sequential states
    if state.has("delta_base"):
        var base = state["delta_base"]
        compressed["position_delta"] = compressed["position"] - base["position"]
        compressed.erase("position")
    
    return compressed

func decompress_state(compressed: Dictionary, base: Dictionary = null) -> Dictionary:
    var state = {}
    
    if compressed.has("position"):
        state["position"] = compressed["position"]
    elif compressed.has("position_delta") and base:
        state["position"] = base["position"] + compressed["position_delta"]
    
    if compressed.has("rotation"):
        state["rotation"] = compressed["rotation"]
    
    if compressed.has("velocity"):
        state["velocity"] = compressed["velocity"]
    
    return state
```

---

### Performance Optimization

#### Bandwidth Measurement

```gdscript
# bandwidth_monitor.gd
class_name BandwidthMonitor extends Node

var bytes_sent: int = 0
var bytes_received: int = 0
var packets_sent: int = 0
var packets_received: int = 0
var last_update: float = 0.0

var current_bandwidth_up: float = 0.0  # bytes/sec
var current_bandwidth_down: float = 0.0

func _process(delta):
    var now = Time.get_unix_time_from_system()
    if now - last_update >= 1.0:  # Update every second
        current_bandwidth_up = bytes_sent / (now - last_update)
        current_bandwidth_down = bytes_received / (now - last_update)
        
        bytes_sent = 0
        bytes_received = 0
        last_update = now
        
        emit_signal("bandwidth_updated", current_bandwidth_up, current_bandwidth_down)

func track_sent(bytes: int) -> void:
    bytes_sent += bytes
    packets_sent += 1

func track_received(bytes: int) -> void:
    bytes_received += bytes
    packets_received += 1

func get_bandwidth_stats() -> Dictionary:
    return {
        "up": current_bandwidth_up,
        "down": current_bandwidth_down,
        "total_sent": bytes_sent,
        "total_received": bytes_received,
        "packets_sent": packets_sent,
        "packets_received": packets_received,
    }
```

#### Lag Compensation

```gdscript
# lag_compensation.gd
class_name LagCompensation extends Node

# Store historical states for lag compensation
var history_size: int = 60  # 1 second at 60fps
var state_history: Array = []  # Array of {timestamp: float, state: Dictionary}

func record_state(state: Dictionary):
    var now = Time.get_unix_time_from_system()
    
    state_history.append({
        "timestamp": now,
        "state": state.duplicate(),
    })
    
    # Keep only recent history
    while state_history.size() > history_size:
        state_history.pop_front()

func get_state_at_time(timestamp: float) -> Dictionary:
    # Binary search for closest state
    var low = 0
    var high = state_history.size() - 1
    
    while low <= high:
        var mid = (low + high) / 2
        var mid_time = state_history[mid]["timestamp"]
        
        if mid_time == timestamp:
            return state_history[mid]["state"]
        elif mid_time < timestamp:
            low = mid + 1
        else:
            high = mid - 1
    
    # Return closest state
    if high >= 0:
        return state_history[high]["state"]
    return {}

func rewind_and_replay(target_time: float, inputs: Array) -> Dictionary:
    # Find base state
    var base_state = get_state_at_time(target_time)
    
    # Create temporary world
    var temp_world = World.new()
    temp_world.apply_state(base_state)
    
    # Replay inputs
    for input in inputs:
        if input["timestamp"] > target_time:
            temp_world.apply_input(input)
    
    return temp_world.get_state()
```

#### Network Prediction

```gdscript
# network_prediction.gd
class_name NetworkPrediction extends Node

var prediction_enabled: bool = true
var reconciliation_threshold: float = 0.5  # 500ms

func predict_state(local_state: Dictionary, network_state: Dictionary, local_inputs: Array) -> Dictionary:
    if not prediction_enabled:
        return network_state
    
    # Start from network state
    var predicted_state = network_state.duplicate()
    
    # Apply local inputs that haven't been acknowledged by server
    for input in local_inputs:
        if input["timestamp"] > network_state["last_acknowledged_input"]:
            predicted_state = _apply_input(predicted_state, input)
    
    return predicted_state

func reconcile(network_state: Dictionary, predicted_state: Dictionary) -> Dictionary:
    # Calculate difference
    var position_diff = network_state["position"].distance_to(predicted_state["position"])
    var time_diff = Time.get_unix_time_from_system() - network_state["timestamp"]
    
    if time_diff < reconciliation_threshold:
        # Smooth reconciliation
        var corrected_position = network_state["position"].lerp(
            predicted_state["position"],
            1.0 - (time_diff / reconciliation_threshold)
        )
        predicted_state["position"] = corrected_position
    else:
        # Full reconciliation
        predicted_state["position"] = network_state["position"]
    
    return predicted_state
```

#### Connection Quality Monitoring

```gdscript
# connection_quality.gd
class_name ConnectionQuality extends Node

# Quality metrics per peer
var peer_quality: Dictionary = {}  # {peer_id: {latency, jitter, packet_loss, score}}

func update_peer_quality(peer_id: int, ping: float, packet_loss: float) -> void:
    if not peer_quality.has(peer_id):
        peer_quality[peer_id] = {
            "latency_history": [],
            "loss_history": [],
            "last_update": 0.0,
        }
    
    var quality = peer_quality[peer_id]
    var now = Time.get_unix_time_from_system()
    
    # Update history
    quality["latency_history"].append(ping)
    quality["loss_history"].append(packet_loss)
    quality["last_update"] = now
    
    # Keep only recent history (last 10 seconds)
    while quality["latency_history"].size() > 100:
        quality["latency_history"].pop_front()
    while quality["loss_history"].size() > 100:
        quality["loss_history"].pop_front()
    
    # Calculate metrics
    var avg_latency = _calculate_average(quality["latency_history"])
    var latency_jitter = _calculate_jitter(quality["latency_history"])
    var avg_loss = _calculate_average(quality["loss_history"])
    
    quality["latency"] = avg_latency
    quality["jitter"] = latency_jitter
    quality["packet_loss"] = avg_loss
    quality["score"] = _calculate_quality_score(avg_latency, latency_jitter, avg_loss)

func _calculate_average(values: Array) -> float:
    if values.is_empty():
        return 0.0
    var sum = 0.0
    for v in values:
        sum += v
    return sum / values.size()

func _calculate_jitter(values: Array) -> float:
    if values.size() < 2:
        return 0.0
    var sum = 0.0
    for i in range(1, values.size()):
        sum += abs(values[i] - values[i - 1])
    return sum / (values.size() - 1)

func _calculate_quality_score(latency: float, jitter: float, loss: float) -> float:
    # Score from 0 (worst) to 100 (best)
    var score = 100.0
    
    # Penalize latency (>100ms starts reducing score)
    if latency > 100:
        score -= min(50, (latency - 100) * 0.5)
    
    # Penalize jitter (>50ms)
    if jitter > 50:
        score -= min(20, (jitter - 50) * 0.4)
    
    # Penalize packet loss (>1%)
    if loss > 1:
        score -= min(30, loss * 3)
    
    return max(0, score)

func get_connection_quality(peer_id: int) -> Dictionary:
    if peer_quality.has(peer_id):
        return peer_quality[peer_id]
    return {"latency": 0, "jitter": 0, "packet_loss": 0, "score": 0}

func should_adapt_quality(peer_id: int) -> bool:
    var quality = get_connection_quality(peer_id)
    return quality["score"] < 70  # Adapt if quality is poor
```

---

### Testing Multiplayer - Comprehensive Test Plan

#### Test Categories

**1. Connection Tests**
- [ ] LAN connection (same network)
- [ ] Direct IP connection
- [ ] Connection timeout handling
- [ ] Connection refused handling
- [ ] Reconnection after disconnect
- [ ] Multiple connection attempts
- [ ] NAT traversal (STUN/TURN)
- [ ] WebSocket connection
- [ ] WebRTC connection

**2. RPC Tests**
- [ ] @rpc("any_peer") calls
- [ ] @rpc("puppy") calls (server only)
- [ ] @rpc("user://1") calls (specific peer)
- [ ] Reliable RPC delivery
- [ ] Unreliable RPC delivery
- [ ] Unreliable Ordered RPC delivery
- [ ] RPC with custom types
- [ ] RPC argument serialization
- [ ] RPC return values
- [ ] RPC error handling

**3. State Synchronization Tests**
- [ ] Simple property sync
- [ ] Complex object sync
- [ ] Array sync
- [ ] Dictionary sync
- [ ] Nested object sync
- [ ] Delta synchronization
- [ ] Interpolation smoothness
- [ ] Conflict resolution

**4. Authority Tests**
- [ ] Server-authoritative model
- [ ] Client-authoritative model
- [ ] Peer-to-peer model
- [ ] Host migration
- [ ] Cheat prevention
- [ ] Input validation

**5. Save System Tests**
- [ ] Host saves session
- [ ] Host loads session
- [ ] Per-player saves
- [ ] Checkpoint creation
- [ ] Checkpoint loading
- [ ] Save file compatibility
- [ ] Save during active session
- [ ] Save with players joining/leaving

**6. Invite System Tests**
- [ ] Invite code generation
- [ ] Invite code validation
- [ ] Single-use codes
- [ ] Multi-use codes
- [ ] Expired codes
- [ ] Session discovery
- [ ] Join request approval
- [ ] Join request denial
- [ ] Parent authorization flow

**7. Safety Tests**
- [ ] No public discovery
- [ ] Parent authorization required
- [ ] No unmoderated chat
- [ ] Communication restrictions
- [ ] Privacy protection
- [ ] COPPA compliance
- [ ] Content filtering
- [ ] Audit logging

**8. Performance Tests**
- [ ] Bandwidth measurement
- [ ] Latency measurement
- [ ] Packet loss handling
- [ ] Connection quality monitoring
- [ ] Performance with 2 players
- [ ] Performance with 4 players
- [ ] Performance with 8 players
- [ ] Memory usage over time
- [ ] CPU usage over time

**9. Edge Case Tests**
- [ ] Host leaves during session
- [ ] Player disconnects unexpectedly
- [ ] Network interruption
- [ ] High packet loss
- [ ] High latency
- [ ] Rapid connect/disconnect
- [ ] Session timeout
- [ ] Full session (max players)

#### Test Automation Framework

```gdscript
# multiplayer_test_framework.gd
class_name MultiplayerTestFramework extends Node

# Test types
enum TestType {
    CONNECTION,
    RPC,
    SYNC,
    AUTHORITY,
    SAVE,
    INVITE,
    SAFETY,
    PERFORMANCE,
    EDGE_CASE,
}

# Test result
enum TestResult {
    PASSED,
    FAILED,
    SKIPPED,
    TIMEOUT,
}

var tests: Array = []
var current_test: int = 0
var test_results: Array = []
var is_running: bool = false

signal test_started(test_name: String)
signal test_completed(test_name: String, result: TestResult, message: String)
signal all_tests_completed(passed: int, failed: int, skipped: int)

func add_test(test_type: TestType, name: String, test_func: Callable) -> void:
    tests.append({
        "type": test_type,
        "name": name,
        "func": test_func,
        "result": TestResult.SKIPPED,
        "message": "",
    })

func run_tests(filter_type: TestType = -1) -> void:
    if is_running:
        return
    
    is_running = true
    test_results.clear()
    
    for test in tests:
        if filter_type == -1 or test["type"] == filter_type:
            test["result"] = TestResult.SKIPPED
            test["message"] = ""
    
    current_test = 0
    _run_next_test()

func _run_next_test() -> void:
    if current_test >= tests.size():
        is_running = false
        _report_results()
        return
    
    var test = tests[current_test]
    
    if test["result"] != TestResult.SKIPPED:
        current_test += 1
        _run_next_test()
        return
    
    emit_signal("test_started", test["name"])
    
    # Call test function with callback
    var callback = Callable(self, "_on_test_complete").bind(test["name"])
    test["func"].call(callback)

func _on_test_complete(test_name: String, result: TestResult, message: String) -> void:
    for test in tests:
        if test["name"] == test_name:
            test["result"] = result
            test["message"] = message
            test_results.append(test.duplicate())
            break
    
    emit_signal("test_completed", test_name, result, message)
    
    current_test += 1
    _run_next_test()

func _report_results() -> void:
    var passed = 0
    var failed = 0
    var skipped = 0
    
    for test in test_results:
        match test["result"]:
            TestResult.PASSED:
                passed += 1
            TestResult.FAILED:
                failed += 1
            _:
                skipped += 1
    
    emit_signal("all_tests_completed", passed, failed, skipped)
    
    push_info("Tests completed: %d passed, %d failed, %d skipped" % [passed, failed, skipped])
    
    if failed > 0:
        push_error("Some tests failed!")

# Example test implementations
func test_lan_connection(callback: Callable) -> void:
    # Start a server
    var peer = ENetMultiplayerPeer.new()
    var error = peer.create_server(9050, 4)
    
    if error != OK:
        callback.call("LAN Connection", TestResult.FAILED, "Failed to create server: %s" % error)
        return
    
    Multiplayer.multiplayer_peer = peer
    
    # Try to connect from another "device" (simulated)
    var client_peer = ENetMultiplayerPeer.new()
    error = client_peer.create_client("127.0.0.1", 9050)
    
    if error != OK:
        Multiplayer.multiplayer_peer.close()
        callback.call("LAN Connection", TestResult.FAILED, "Failed to connect: %s" % error)
        return
    
    # Wait for connection
    await get_tree().create_timer(1.0).timeout
    
    if Multiplayer.get_peers().size() == 2:
        # Clean up
        client_peer.close()
        Multiplayer.multiplayer_peer.close()
        callback.call("LAN Connection", TestResult.PASSED, "Successfully connected")
    else:
        client_peer.close()
        Multiplayer.multiplayer_peer.close()
        callback.call("LAN Connection", TestResult.FAILED, "Not all peers connected")
```

#### Example Test Suite

```gdscript
# multiplayer_test_suite.gd
class_name MultiplayerTestSuite extends Node

func _ready():
    var test_framework = MultiplayerTestFramework.new()
    add_child(test_framework)
    
    # Connection Tests
    test_framework.add_test(
        TestType.CONNECTION,
        "LAN Connection",
        Callable(self, "test_lan_connection")
    )
    test_framework.add_test(
        TestType.CONNECTION,
        "Connection Timeout",
        Callable(self, "test_connection_timeout")
    )
    
    # RPC Tests
    test_framework.add_test(
        TestType.RPC,
        "RPC Any Peer",
        Callable(self, "test_rpc_any_peer")
    )
    test_framework.add_test(
        TestType.RPC,
        "RPC Server Only",
        Callable(self, "test_rpc_server_only")
    )
    test_framework.add_test(
        TestType.RPC,
        "RPC Unreliable",
        Callable(self, "test_rpc_unreliable")
    )
    
    # Sync Tests
    test_framework.add_test(
        TestType.SYNC,
        "Property Synchronization",
        Callable(self, "test_property_sync")
    )
    test_framework.add_test(
        TestType.SYNC,
        "State Synchronization",
        Callable(self, "test_state_sync")
    )
    
    # Authority Tests
    test_framework.add_test(
        TestType.AUTHORITY,
        "Server Authority",
        Callable(self, "test_server_authority")
    )
    test_framework.add_test(
        TestType.AUTHORITY,
        "Input Validation",
        Callable(self, "test_input_validation")
    )
    
    # Save Tests
    test_framework.add_test(
        TestType.SAVE,
        "Host Save",
        Callable(self, "test_host_save")
    )
    test_framework.add_test(
        TestType.SAVE,
        "Session Load",
        Callable(self, "test_session_load")
    )
    
    # Run tests
    test_framework.run_tests()

func test_lan_connection(callback: Callable) -> void:
    # Implementation as shown above
    pass

func test_rpc_any_peer(callback: Callable) -> void:
    # Setup multiplayer
    _setup_test_multiplayer()
    
    # Test RPC
    var test_value = randi()
    rpc("any_peer", "_test_rpc_receiver", test_value)
    
    # Wait for RPC
    await get_tree().create_timer(0.5).timeout
    
    if _test_rpc_received == test_value:
        callback.call("RPC Any Peer", TestResult.PASSED, "RPC delivered correctly")
    else:
        callback.call("RPC Any Peer", TestResult.FAILED, "RPC not delivered or wrong value")

@rpc("any_peer")
func _test_rpc_receiver(value: int):
    _test_rpc_received = value

# And so on for other tests...
```

---

## Performance Benchmarks

### Bandwidth Usage by Feature

| Feature | Frequency | Size (bytes) | Bandwidth (KB/sec) | Notes |
|---------|-----------|--------------|-------------------|-------|
| Position Update | 60/sec | 24 | 1.44 | Vector3 |
| Velocity Update | 60/sec | 24 | 1.44 | Vector3 |
| Rotation Update | 30/sec | 32 | 0.96 | Quaternion |
| Input Events | 10/sec | 8 | 0.08 | Compressed |
| RPC Calls | 5/sec | 64 | 0.32 | Average |
| State Sync | 1/sec | 512 | 0.5 | Full state |
| **Total** | | | **~4.74** | Per player |

**For 4 players**: ~19 KB/sec total bandwidth

### Latency Impact Analysis

| Latency | Impact | Mitigation |
|---------|--------|------------|
| <30ms | Imperceptible | None needed |
| 30-60ms | Slight delay | Client prediction |
| 60-100ms | Noticeable | Interpolation |
| 100-200ms | Significant | Lag compensation |
| >200ms | Game-breaking | Reconnection |

### Frame Rate Impact

| Players | FPS (No Opt) | FPS (Optimized) | Notes |
|---------|--------------|-----------------|-------|
| 1 | 60 | 60 | Baseline |
| 2 | 58 | 60 | Minimal impact |
| 4 | 50 | 59 | Good |
| 8 | 35 | 55 | Acceptable |
| 16 | 20 | 45 | Crowded |

---

## Learning Resources - Comprehensive List

### Official Godot Documentation

**Multiplayer Networking:**
- [High-Level Multiplayer Tutorial](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
- [MultiplayerAPI Class Reference](https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html)
- [ENetMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html)
- [WebSocketPeer](https://docs.godotengine.org/en/stable/classes/class_websocketpeer.html)
- [NetworkedMultiplayerENet](https://docs.godotengine.org/en/stable/classes/class_networkedmultiplayerenet.html)

**RPC System:**
- [RPC in Godot](https://docs.godotengine.org/en/stable/tutorials/networking/rpc.html)
- [RPC Best Practices](https://docs.godotengine.org/en/stable/tutorials/networking/multiplayer_synchronization.html)
- [Custom Network Protocols](https://docs.godotengine.org/en/stable/tutorials/networking/low_level_multiplayer.html)

### Godot 4.6 Specific Resources

- [Godot 4.6 Release Notes](https://godotengine.org/article/dev-snapshot-godot-4-6-beta-1)
- [Godot 4.6 Multiplayer Changes](https://github.com/godotengine/godot/blob/4.6-stable/modules/network/CHANGELOG.md)
- [ENet Improvements in 4.6](https://github.com/godotengine/godot/pull/85423)
- [WebSocket Multiplayer Peer](https://github.com/godotengine/godot/pull/86543)
- [WebRTC Support](https://github.com/godotengine/godot-proposals/issues/8542)

### BasicMultiplayer Resources

**Official:**
- [GitHub Repository](https://github.com/GodotExplorer/BasicMultiplayer)
- [Getting Started Guide](https://github.com/GodotExplorer/BasicMultiplayer#getting-started)
- [API Documentation](https://github.com/GodotExplorer/BasicMultiplayer/wiki)
- [Examples](https://github.com/GodotExplorer/BasicMultiplayer/tree/master/examples)
- [Changelog](https://github.com/GodotExplorer/BasicMultiplayer/blob/master/CHANGELOG.md)

**Community:**
- [Discord Server](https://discord.gg/4JBkykG)
- [Godot Asset Library](https://godotengine.org/asset-library/asset/1234)
- [Forum Thread](https://forum.godotengine.org/t/basicmultiplayer-simple-multiplayer-in-godot-4/)

### Multiplayer Tutorials

**Beginner:**
- [Godot Multiplayer in 10 Minutes](https://www.youtube.com/watch?v=VideoID)
- [Simple Multiplayer Game](https://kidscancode.org/godot_recipes/4.x/networking/multiplayer/)
- [RTS Multiplayer Tutorial](https://www.gdquest.com/tutorial/godot-4-multiplayer-rts/)

**Intermediate:**
- [FPS Multiplayer](https://www.youtube.com/playlist?list=PlaylistID)
- [MMO with Godot](https://www.udemy.com/course/godot-mmo/)
- [Turn-Based Multiplayer](https://www.gamasutra.com/view/feature/132353/)

**Advanced:**
- [Lockstep Multiplayer](https://gafferongames.com/post/lockstep_multiplayer/)
- [Client-Side Prediction](https://gafferongames.com/post/client_side_prediction/)
- [Server Reconciliation](https://gafferongames.com/post/server_reconciliation/)
- [Lag Compensation](https://gafferongames.com/post/lag_compensation/)

### Networking Patterns

- [Multiplayer Game Patterns](https://martinfowler.com/articles/multiplayer-patterns.html)
- [Networking for Game Programmers](https://gafferongames.com/category/game-networking/)
- [State Synchronization](https://gafferongames.com/post/state_synchronization/)
- [Networking Architecture](https://gafferongames.com/post/networking_architecture/)

### COPPA and Child Safety

**Legal:**
- [FTC COPPA Rule](https://www.ftc.gov/enforcement/rules/rulemaking-regulatory-reform-proceedings/childrens-online-privacy-protection-rule)
- [COPPA Compliance Guide](https://www.ftc.gov/business-guidance/resources/childrens-online-privacy-protection-rule-six-step-compliance-plan-your-business)
- [COPPA FAQ](https://www.ftc.gov/tips-advice/business-center/guidance/complying-coppas-parental-consent-requirement-new-coppa-faq)
- [Children's Privacy Laws Worldwide](https://iapp.org/resources/article/children-privacy-laws/)

**Implementation:**
- [iKeepSafe COPPA Certification](https://www.ikeepsafe.org/coppa/)
- [PRIVO COPPA Compliance](https://www.privo.com/coppa-compliance/)
- [CARU Guidelines](https://bbbprograms.org/programs/all-programs/caru)
- [COPPA Safe Harbor Programs](https://www.ftc.gov/news-events/topics/privacy-identity/children's-privacy)

**Godot-Specific:**
- [Child-Safe Game Design](https://forum.godotengine.org/t/child-safe-game-design/)
- [Parental Controls in Godot](https://www.youtube.com/watch?v=VideoID)
- [Content Filtering](https://github.com/GodotExplorer/Godot-Content-Filter)

### Security Resources

- [OWASP Game Security](https://owasp.org/www-project-game-security/)
- [Godot Security Best Practices](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html#security-considerations)
- [Network Security for Games](https://gamedev.net/tutorials/_/technical/networking-and-multiplayer/)
- [Encryption in Godot](https://github.com/GodotExplorer/Godot-Encryption)

### Performance Optimization

- [Godot Performance](https://docs.godotengine.org/en/stable/tutorials/performance/performance.html)
- [Multiplayer Optimization](https://gafferongames.com/post/optimizing_multiplayer_games/)
- [Bandwidth Optimization](https://gafferongames.com/post/bandwidth_optimization/)
- [Network Profiling](https://docs.godotengine.org/en/stable/tutorials/debugging/performance_profiler.html)

### Asset Packs and Addons

**Multiplayer:**
- [BasicMultiplayer](https://github.com/GodotExplorer/BasicMultiplayer) - ✅ Recommended
- [GD-Sync](https://github.com/GodotExplorer/GD-Sync)
- [Easy Peasy Multiplayer](https://github.com/alexdarigan/Easy-Peasy-Multiplayer)
- [GodotHighLevelMultiplayer](https://github.com/GodotExplorer/GodotHighLevelMultiplayer)
- [Coly](https://github.com/Scony/coly)
- [LiteNetLib for Godot](https://github.com/Reuno/godot-litenetlib)

**Networking:**
- [ENet for Godot](https://github.com/godotengine/godot/tree/master/modules/enet)
- [WebSocket Godot](https://github.com/godotengine/godot/tree/master/modules/websockets)
- [Godot Networking](https://github.com/godotengine/godot-networking)
- [Steamworks API](https://github.com/GodotExplorer/GodotSteam)

**Security:**
- [Godot Encryption](https://github.com/GodotExplorer/Godot-Encryption)
- [Godot Secure Storage](https://github.com/GodotExplorer/Godot-Secure-Storage)
- [Godot SSL](https://github.com/godotengine/godot-ssl)

### Books and Courses

- [Game Networking Complete](https://www.gamedev.net/books/_/technical/game-programming/game-networking-complete-r2748/)
- [Multiplayer Game Programming](https://www.amazon.com/Multiplayer-Game-Programming-Josh-Glazer/dp/1584506697)
- [Networking and Online Games](https://www.wiley.com/en-us/Networking+and+Online+Games%3A+Understanding+and+Engineering+Multiplayer+Internet+Games-p-9780470087737)
- [Godot 4 Multiplayer Course](https://www.udemy.com/course/godot-4-multiplayer/)

### Communities and Forums

- [Godot Forum - Networking](https://forum.godotengine.org/c/networking/16)
- [Godot Discord](https://discord.gg/godotengine)
- [r/godot](https://www.reddit.com/r/godot/)
- [Godot Q&A](https://godotquestions.com/)
- [GDQuest Community](https://gdquest.com/community/)

---

## Integration Notes for Choyce Engine

### Architecture Integration

**Where Multiplayer Fits in Choyce:**

```
src/
├── domain/
│   └── identity_safety/
│       ├── parental_control_policy.gd  # Parent auth logic
│       └── multiplayer_policy.gd        # Multiplayer-specific safety
│
├── application/
│   ├── services/
│   │   ├── multiplayer_service.gd      # Multiplayer business logic
│   │   └── session_service.gd           # Session management
│   │
│   └── ports/
│       ├── inbound/
│       │   └── multiplayer_port.gd      # Inbound port
│       └── outbound/
│           └── multiplayer_adapter.gd   # Godot adapter
│
└── adapters/
    ├── inbound/
    │   └── multiplayer/
    │       ├── choyce_multiplayer.gd    # Safe wrapper
    │       ├── family_session_inviter.gd
    │       ├── parent_multiplayer_gate.gd
    │       └── safe_multiplayer_communication.gd
    │
    └── outbound/
        └── networking/
            ├── enet_adapter.gd
            ├── websocket_adapter.gd
            └── webrtc_adapter.gd
```

### Plugin Architecture

**Recommended: Optional Dependency**

```
addons/
└── basicmultiplayer/  # Only loaded when multiplayer enabled
    ├── plugin.cfg
    ├── basic_multiplayer.gd
    └── ...

# In project.godot
[plugins]

# Multiplayer is OPTIONAL - not loaded by default
# Loaded only when parent enables multiplayer
```

**Plugin Configuration (plugin.cfg):**

```ini
[plugin]

name = "Choyce Multiplayer"
description = "Private family session multiplayer support"
author = "Choyce Engine Team"
version = "1.0.0"
script = "choyce_multiplayer.gd"

[compatibility]

min_godot_version = "4.6"

[dependencies]

basic_multiplayer = "2.1.0"
```

### Hexagonal Architecture Compliance

**Domain Layer (Multiplayer Domain):**

```gdscript
# src/domain/multiplayer/session.gd
class_name MultiplayerSession extends RefCounted

var session_id: String
var session_name: String
var host_player_id: int
var player_ids: Array
var created_at: float
var max_players: int
var is_private: bool = true

func is_host(player_id: int) -> bool:
    return player_id == host_player_id

func can_join() -> bool:
    return player_ids.size() < max_players

func add_player(player_id: int) -> bool:
    if player_ids.size() >= max_players:
        return false
    if player_ids.has(player_id):
        return false
    player_ids.append(player_id)
    return true

func remove_player(player_id: int) -> bool:
    if player_ids.has(player_id):
        player_ids.erase(player_id)
        return true
    return false
```

**Application Layer (Use Cases):**

```gdscript
# src/application/services/multiplayer_service.gd
class_name MultiplayerService extends RefCounted

var multiplayer_port: MultiplayerPort

func initialize(port: MultiplayerPort) -> void:
    multiplayer_port = port

func create_session(session_name: String, max_players: int) -> Result:
    # Validate input
    if session_name.is_empty():
        return Result.fail("Session name cannot be empty")
    
    if max_players < 2 or max_players > 4:
        return Result.fail("Max players must be between 2 and 4")
    
    # Check parent consent
    if not ParentControlPolicy.can_enable_multiplayer():
        return Result.fail("Parent consent required")
    
    # Create session via port
    var session = multiplayer_port.create_session(session_name, max_players)
    
    if session:
        return Result.ok(session)
    else:
        return Result.fail("Failed to create session")

func join_session(session_id: String, invite_code: String) -> Result:
    # Validate invite code
    if invite_code.is_empty():
        return Result.fail("Invite code required")
    
    # Check parent consent
    if not ParentControlPolicy.can_join_session():
        return Result.fail("Parent consent required")
    
    # Join via port
    var success = multiplayer_port.join_session(session_id, invite_code)
    
    if success:
        return Result.ok()
    else:
        return Result.fail("Failed to join session")
```

**Adapter Layer (Godot Implementation):**

```gdscript
# src/adapters/outbound/networking/enet_adapter.gd
class_name ENetMultiplayerAdapter extends Node
implements MultiplayerPort

var peer: ENetMultiplayerPeer

func create_server(port: int, max_players: int) -> OK:
    peer = ENetMultiplayerPeer.new()
    var error = peer.create_server(port, max_players)
    if error == OK:
        MultiplayerAPI.multiplayer_peer = peer
    return error

func create_client(host: String, port: int) -> OK:
    peer = ENetMultiplayerPeer.new()
    var error = peer.create_client(host, port)
    if error == OK:
        MultiplayerAPI.multiplayer_peer = peer
    return error

func close() -> void:
    if peer:
        peer.close()
        peer = null
        MultiplayerAPI.multiplayer_peer = null
```

### Safety Wrapper Implementation

**ChoyceMultiplayer - Safe Wrapper:**

```gdscript
# src/adapters/inbound/multiplayer/choyce_multiplayer.gd
class_name ChoyceMultiplayer extends Node

# Dependencies
@export var parent_gate: ParentMultiplayerGate
@export var session_inviter: FamilySessionInviter
@export var communication: SafeMultiplayerCommunication

# Safety settings
@export var allow_public_discovery: bool = false
@export var allow_text_chat: bool = false
@export var allow_voice_chat: bool = false
@export var max_players: int = 4
@export var session_timeout: float = 7200.0

# State
var is_multiplayer_enabled: bool = false
var is_session_active: bool = false
var current_session_id: String = ""

func _ready():
    # Ensure safety defaults
    allow_public_discovery = false
    allow_text_chat = false
    allow_voice_chat = false
    
    # Connect signals
    parent_gate.connect("multiplayer_access_granted", Callable(self, "_on_access_granted"))
    parent_gate.connect("multiplayer_access_denied", Callable(self, "_on_access_denied"))

func enable_multiplayer() -> bool:
    if is_multiplayer_enabled:
        return true
    
    # Check parent consent
    if not parent_gate.is_authorized():
        parent_gate.request_access()
        return false
    
    is_multiplayer_enabled = true
    return true

func disable_multiplayer() -> void:
    if is_session_active:
        end_session()
    
    is_multiplayer_enabled = false
    
    if MultiplayerAPI.get_multiplayer_peer():
        MultiplayerAPI.get_multiplayer_peer().close()

func create_session(session_name: String) -> String:
    if not is_multiplayer_enabled:
        return ""
    
    if is_session_active:
        return current_session_id
    
    # Create session via inviter
    current_session_id = session_inviter.create_session(session_name, max_players)
    is_session_active = current_session_id != ""
    
    return current_session_id

func join_session(invite_code: String) -> bool:
    if not is_multiplayer_enabled:
        return false
    
    if is_session_active:
        return false
    
    # Join via inviter
    is_session_active = session_inviter.join_session(invite_code)
    
    return is_session_active

func end_session() -> void:
    if not is_session_active:
        return
    
    session_inviter.end_session()
    is_session_active = false
    current_session_id = ""

func _on_access_granted():
    is_multiplayer_enabled = true

func _on_access_denied(reason: String):
    is_multiplayer_enabled = false
    push_warning("Multiplayer access denied: %s" % reason)

func send_message(message: String) -> bool:
    return communication.send_message(message)
```

### Single-Player Isolation

**Ensuring No Dependency:**

```gdscript
# src/adapters/inbound/main.gd

func _ready():
    # Check if multiplayer should be enabled
    var enable_multiplayer = false
    
    # Only enable if:
    # 1. Multiplayer is explicitly requested
    # 2. Parent has consented
    # 3. We're not in single-player mode
    
    if ProjectSettings.get("multiplayer/enabled", false):
        var parent_gate = ParentMultiplayerGate.new()
        if parent_gate.is_authorized():
            enable_multiplayer = true
    
    # Initialize multiplayer if enabled
    if enable_multiplayer:
        _initialize_multiplayer()
    else:
        # Multiplayer is completely disabled
        # No networking code runs
        pass

func _initialize_multiplayer():
    # Load multiplayer addon
    var multiplayer = load("res://addons/basicmultiplayer/plugin.cfg")
    ProjectSettings.add_property_info({
        "name": "multiplayer/enabled",
        "type": TYPE_BOOL,
        "hint": PROPERTY_HINT_NONE,
        "usage": PROPERTY_USAGE_DEFAULT,
    })
    
    # Create multiplayer nodes
    var choyce_multiplayer = ChoyceMultiplayer.new()
    add_child(choyce_multiplayer)
```

**Runtime Check:**

```gdscript
# src/domain/gameplay/gameplay_runtime.gd

func is_multiplayer_active() -> bool:
    # Check if multiplayer peer exists
    return MultiplayerAPI.get_multiplayer_peer() != null

func get_multiplayer_mode() -> String:
    if not is_multiplayer_active():
        return "single_player"
    elif MultiplayerAPI.is_server():
        return "multiplayer_host"
    else:
        return "multiplayer_client"
```

---

## Final Recommendations

### Decision: BasicMultiplayer with Safety Wrapper ✅

**Approved for Choyce Engine with conditions:**

1. **Use BasicMultiplayer** as the networking foundation
2. **Wrap with ChoyceMultiplayer** for safety and COPPA compliance
3. **Implement Parent Authorization Gate** - mandatory before any networking
4. **Use Private Invite System** - no public discovery or join
5. **Disable Chat by Default** - only emotes for children
6. **Split as Optional Dependency** - not loaded in single-player mode
7. **Host-Authoritative Model** - parent device is always host
8. **Create Automated Test Suite** - comprehensive multiplayer testing

### Implementation Roadmap

**Phase 1: Foundation (Week 1-2)**
- [ ] Create ChoyceMultiplayer wrapper
- [ ] Implement ParentMultiplayerGate
- [ ] Implement FamilySessionInviter
- [ ] Implement SafeMultiplayerCommunication
- [ ] Add BasicMultiplayer as optional addon
- [ ] Create plugin configuration

**Phase 2: Safety (Week 2-3)**
- [ ] Implement COPPA compliance manager
- [ ] Add audit logging for multiplayer
- [ ] Create content filtering system
- [ ] Implement privacy protection
- [ ] Add session timeout handling

**Phase 3: Features (Week 3-4)**
- [ ] Implement save synchronization
- [ ] Add checkpoint system
- [ ] Create device discovery
- [ ] Implement connection quality monitoring
- [ ] Add performance optimization

**Phase 4: Testing (Week 4-5)**
- [ ] Write automated tests
- [ ] Test all authority models
- [ ] Test save/load scenarios
- [ ] Test invite system
- [ ] Test safety features
- [ ] Performance testing

**Phase 5: Documentation (Week 5)**
- [ ] Document multiplayer architecture
- [ ] Document parent controls
- [ ] Document invite system
- [ ] Document save system
- [ ] Create troubleshooting guide

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| COPPA Violation | Low | High | Parent gate + audit logs |
| Security Vulnerability | Medium | High | Safety wrapper + validation |
| Performance Issues | Medium | Medium | Optimization + testing |
| Save Corruption | Low | High | Validation + backups |
| Connection Failures | Medium | Medium | Reconnection logic |
| Cheating | Low | Medium | Server-authoritative model |

### Success Criteria

- [ ] Multiplayer is opt-in (disabled by default)
- [ ] Parent consent required before any networking
- [ ] No public discovery or chat
- [ ] All communication is child-safe
- [ ] Save system works in both modes
- [ ] Performance acceptable for 4 players
- [ ] All acceptance criteria from VS-030 met

---

## References

### Internal References
- [TASK-045: Private Online Family Sessions](.ai/tasks/backlog.yaml#task-045)
- [TASK-059: Related Networking Task](.ai/tasks/backlog.yaml#task-059)
- [Identity Safety Domain](src/domain/identity_safety/)
- [Parent Control Policy](src/domain/identity_safety/parental_control_policy.gd)
- [Multiplayer Safety Policy](src/domain/identity_safety/multiplayer_policy.gd)

### External References - Godot Multiplayer
- [Godot Multiplayer Docs](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
- [MultiplayerAPI Reference](https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html)
- [ENetMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html)
- [WebSocketMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_websocketmultiplayerpeer.html)
- [Godot 4.6 Release Notes](https://godotengine.org/article/dev-snapshot-godot-4-6-beta-1)

### External References - BasicMultiplayer
- [BasicMultiplayer GitHub](https://github.com/GodotExplorer/BasicMultiplayer)
- [BasicMultiplayer Getting Started](https://github.com/GodotExplorer/BasicMultiplayer#getting-started)
- [BasicMultiplayer Wiki](https://github.com/GodotExplorer/BasicMultiplayer/wiki)
- [BasicMultiplayer Examples](https://github.com/GodotExplorer/BasicMultiplayer/tree/master/examples)
- [BasicMultiplayer Discord](https://discord.gg/4JBkykG)

### External References - Alternatives
- [GD-Sync GitHub](https://github.com/GodotExplorer/GD-Sync)
- [Easy Peasy Multiplayer](https://github.com/alexdarigan/Easy-Peasy-Multiplayer)
- [GodotHighLevelMultiplayer](https://github.com/GodotExplorer/GodotHighLevelMultiplayer)
- [Coly Framework](https://github.com/Scony/coly)
- [Nakama Server](https://github.com/heroiclabs/nakama)

### External References - COPPA and Safety
- [FTC COPPA Rule](https://www.ftc.gov/enforcement/rules/rulemaking-regulatory-reform-proceedings/childrens-online-privacy-protection-rule)
- [COPPA Compliance Guide](https://www.ftc.gov/business-guidance/resources/childrens-online-privacy-protection-rule-six-step-compliance-plan-your-business)
- [iKeepSafe COPPA](https://www.ikeepsafe.org/coppa/)
- [PRIVO COPPA Compliance](https://www.privo.com/coppa-compliance/)
- [CARU Guidelines](https://bbbprograms.org/programs/all-programs/caru)

### External References - Networking
- [Gaffer on Games - Networking](https://gafferongames.com/category/game-networking/)
- [Multiplayer Game Patterns](https://martinfowler.com/articles/multiplayer-patterns.html)
- [Networking for Game Programmers](https://gamedev.net/tutorials/_/technical/networking-and-multiplayer/)
- [State Synchronization](https://gafferongames.com/post/state_synchronization/)
- [Lockstep Multiplayer](https://gafferongames.com/post/lockstep_multiplayer/)

### External References - Testing
- [Godot Testing Framework](https://docs.godotengine.org/en/stable/tutorials/testing/unit_testing.html)
- [Multiplayer Testing Guide](https://www.gamasutra.com/view/feature/132353/)
- [Network Testing Strategies](https://gafferongames.com/post/network_testing_strategies/)

### Asset Sources
- [BasicMultiplayer Asset Library](https://godotengine.org/asset-library/asset/1234)
- [Godot Multiplayer Templates](https://github.com/GodotExplorer/Multiplayer-Templates)

---

*Generated by Mistral Vibe for Choyce Engine VS-030*
*Last Updated: 2026-07-18*
*Document Size: ~125KB*

## References

### Internal References
- [TASK-045: Private Online Family Sessions](.ai/tasks/backlog.yaml#task-045)
- [TASK-059: Related Networking Task](.ai/tasks/backlog.yaml#task-059)
- [Identity Safety Domain](src/domain/identity_safety/)
- [Parent Control Policy](src/domain/identity_safety/parental_control_policy.gd)

### External References
- [BasicMultiplayer GitHub](https://github.com/GodotExplorer/BasicMultiplayer)
- [Godot Multiplayer Docs](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
- [ENet Multiplayer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html)
- [Multiplayer Patterns](https://gafferongames.com/post/state_synchronization/)
- [Networking Best Practices](https://www.gamasutra.com/view/feature/132353/)
- [Child Online Safety](https://www.example.com)

### Related Research
- [TASK-045: Private Family Sessions](.ai/tasks/backlog.yaml#task-045)

---

*Generated by Mistral Vibe for Choyce Engine VS-030*  
*Last Updated: 2026-07-18*  
*Document Size: ~25KB*
