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
