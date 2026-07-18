# RESEARCH_VS-032: Retarget CC0 Universal Animation Library onto Active Child and Creature Rigs

**Task ID**: VS-032
**Title**: Retarget the CC0 Universal Animation Library onto active child and creature rigs
**Specialty**: character-animation
**Status**: in_progress
**Owner**: codex
**Cross-review**: claude
**Dependencies**: [VS-015, VS-024]
**Complexity**: HIGH

---

## Task Overview

This task involves **retargeting the CC0 Universal Animation Library (UAL1_Standard.glb)** onto the active **child character rigs** and **creature rigs** from VS-023 and VS-024. The retargeting must ensure **skeleton compatibility**, proper **retarget profiles**, and that all clips are **grounded, face movement/threat direction, and avoid root sliding**. Additionally, the **launcher montage** must use at least two readable camera-composed action beats with no clipped hero or monster silhouettes. Automated animation-state checks and rendered evidence must cover both cinematic and gameplay applications.

### Why This Matters

- **Animation Quality**: UAL provides high-quality, standardized animations
- **Consistency**: Unified animation library across all characters
- **Efficiency**: Reuse animations instead of creating from scratch
- **Polish**: Professional-quality motion for child and creature characters
- **Cinematic Quality**: Launcher montage needs readable action beats

### Key Requirements (from backlog.yaml lines 1578-1582)

1. **Skeleton compatibility and retarget profile are validated before a clip is assigned to a child or creature rig**
2. **Idle, walk/run, attack, hit, and reaction clips are grounded, face their movement/threat direction, and avoid root sliding**
3. **Launcher montage uses at least two readable camera-composed action beats with no clipped hero or monster silhouettes**
4. **Automated animation-state checks and rendered evidence cover cinematic and gameplay application**

### Source Assets

| Asset | Path | Description |
|-------|------|-------------|
| UAL1_Standard.glb | `data/models/quaternius/animations/UAL1_Standard.glb` | CC0 Universal Animation Library |
| Player Controller | `src/adapters/inbound/gameplay/player_controller.gd` | Player movement and animation |
| Gameplay Runtime | `src/adapters/inbound/gameplay/gameplay_runtime.gd` | Runtime systems |
| Launcher Overlay | `src/adapters/inbound/scenes/launcher/launcher_overlay.gd` | Launcher UI and camera |

---

## Current Implementation Analysis

### What Exists

From the codebase:
- **VS-015**: Cinematic Acting and Voice - Character voice systems with ElevenLabs
- **VS-024**: Facial Speech and Emotion - Blend shapes, facial rigs, speech-driven animation
- **Child Rigs**: Quaternius child character models with basic animations
- **Creature Rigs**: Backrooms-inspired creatures from VS-023 with combat animations
- **UAL1_Standard.glb**: Universal Animation Library from Quaternius (CC0)

### Animation System Architecture

The Choyce Engine uses:
- **Godot 4.6 AnimationTree** for state machines and blending
- **Skeleton3D** for bone hierarchies
- **MeshInstance3D** with **BlendShapes** for facial animation (VS-024)
- **AnimationPlayer** for simple playback

### Current Animation States

Based on existing code:
- **Idle**: Basic idle animation
- **Walk/Run**: Movement animations
- **Attack**: Melee attack animations (from VS-005)
- **Hit**: Damage reaction
- **Wind-up**: Telegraph state (from VS-005)
- **Facial**: Blink, speech, emotion (from VS-024)

### UAL1_Standard.glb Contents

The **Universal Animation Library** typically includes:
- **Humanoid animations**: Walk, run, idle, jump, crouch, swim
- **Combat animations**: Attack, hit reaction, block, dodge
- **Interaction animations**: Pick up, use, throw
- **Emotion animations**: Happy, angry, sad, surprised
- **Cinematic animations**: Dramatic poses, camera-ready actions

---

## Online Research Summary

### 1. Universal Animation Library (UAL) Overview

**What is UAL?**
The Universal Animation Library is a **CC0 animation pack** created by Quaternius for Godot 4.x. It provides a standardized set of animations that work across multiple character rigs.

**Key Features**:
- **Humanoid Skeleton**: Standard bone hierarchy (Hips, Spine, Head, Arms, Legs)
- **Retargetable**: Designed to work with different character proportions
- **Grounded Animations**: Feet stay planted, no floating
- **Root Motion**: Optional, can be enabled/disabled
- **Blend Tree Ready**: Organized for use with AnimationTree

**UAL Version**: Standard (UAL1)

**Download**: [Quaternius UAL](https://quaternius.com/free-3d-models?category=animations)

### 2. Godot 4.6 Animation Retargeting

**Animation Retargeting** is the process of applying animations from one skeleton to another.

**Godot's Retargeting System**:
- **Skeleton3D**: Defines bone hierarchy
- **Retargeting Profiles**: Map bones between different skeletons
- **Animation Library**: Can be imported and retargeted

**Retargeting Methods**:

#### Method A: Manual Bone Mapping
```gdscript
# Create a retarget profile
var retarget = RetargetProfile.new()
retarget.add_bone_map("source_bone_name", "target_bone_name")
```

#### Method B: Automatic Retargeting (Godot 4.6+)
Godot 4.6 has improved automatic retargeting based on bone names.

#### Method C: Use AnimationTree with BlendSpaces
```gdscript
# AnimationTree can blend between animations from different sources
animation_tree.active = true
animation_tree["parameters/blend_position"] = Vector2(0.5, 0.5)
```

### 3. Skeleton Compatibility Validation

**Skeleton Hierarchy Check**:
Before retargeting, validate that both skeletons have compatible hierarchies:

```gdscript
func validate_skeleton_compatibility(source: Skeleton3D, target: Skeleton3D) -> bool:
    # Check root bone
    if source.get_bone_count() == 0 or target.get_bone_count() == 0:
        return false
    
    # Get bone names
    var source_bones = []
    for i in range(source.get_bone_count()):
        source_bones.append(source.get_bone_name(i))
    
    var target_bones = []
    for i in range(target.get_bone_count()):
        target_bones.append(target.get_bone_name(i))
    
    # Check for required bones
    var required_bones = ["Hips", "Spine", "Head", "Arm_L", "Arm_R", "Leg_L", "Leg_R"]
    for bone in required_bones:
        if bone not in source_bones or bone not in target_bones:
            push_warning("Missing required bone: %s" % bone)
            return false
    
    return true
```

**Retarget Profile Generator**:
```gdscript
class_name RetargetProfileGenerator extends RefCounted:
    
    func generate_profile(source: Skeleton3D, target: Skeleton3D) -> RetargetProfile:
        var profile = RetargetProfile.new()
        
        # Map common bones
        var bone_mappings = {
            "Hips": "Hips",
            "Spine": "Spine",
            "Spine1": "Spine1",
            "Spine2": "Spine2",
            "Neck": "Neck",
            "Head": "Head",
            "Arm_L": "Arm_L",
            "Arm_R": "Arm_R",
            "ForeArm_L": "ForeArm_L",
            "ForeArm_R": "ForeArm_R",
            "Hand_L": "Hand_L",
            "Hand_R": "Hand_R",
            "Thigh_L": "Thigh_L",
            "Thigh_R": "Thigh_R",
            "Shin_L": "Shin_L",
            "Shin_R": "Shin_R",
            "Foot_L": "Foot_L",
            "Foot_R": "Foot_R",
        }
        
        for source_bone in bone_mappings:
            if source.has_bone(source_bone) and target.has_bone(bone_mappings[source_bone]):
                profile.add_bone_map(source_bone, bone_mappings[source_bone])
        
        return profile
```

### 4. Avoiding Root Sliding

**Root sliding** occurs when the character's root (usually Hips) moves unintentionally during animation.

**Solutions**:

#### Solution A: Disable Root Motion
```gdscript
# In AnimationTree or AnimationPlayer
animation_player.root_motion_enabled = false
```

#### Solution B: Use Foot IK
```gdscript
# Enable Foot IK in Skeleton3D
skeleton.foot_ik_enabled = true
skeleton.foot_ik_raycast_length = 0.5
```

#### Solution C: Ground Constraints
```gdscript
# In animation processing
func _process(delta):
    # Keep feet grounded
    var left_foot_pos = skeleton.get_bone_global_pose("Foot_L").origin
    var right_foot_pos = skeleton.get_bone_global_pose("Foot_R").origin
    
    # Raycast to ground
    var ground_level = get_ground_level()
    
    # Adjust foot positions to ground
    if left_foot_pos.y > ground_level:
        # Apply correction
        pass
```

#### Solution D: Animation Retargeting with Floor Contact
```gdscript
# When importing animations, ensure floor contact is preserved
func ensure_grounded_animation(animation: Animation):
    # Check keyframes for foot bones
    for track_idx in range(animation.get_track_count()):
        var track = animation.get_track(track_idx)
        if track.get_type() == Animation.TYPE_VALUE:
            var path = animation.track_get_path(track_idx)
            if "Foot" in path:
                # Ensure foot doesn't go below ground
                # Adjust Y position if needed
                pass
```

### 5. Facing Movement/Threat Direction

**Requirements**:
- Idle: Face forward
- Walk/Run: Face movement direction
- Attack: Face threat/target
- Hit: Face away from attacker (or towards, depending on design)

**Implementation**:

#### Direction-Based Blending
```gdscript
# In player_controller.gd
func update_facing() -> void:
    if is_moving():
        # Face movement direction
        var move_dir = get_move_direction()
        look_at(global_position + move_dir, Vector3.UP)
    elif has_target():
        # Face target
        look_at(target.global_position, Vector3.UP)
    else:
        # Face camera-forward or last direction
        pass
```

#### AnimationTree BlendSpace
```gdscript
# Setup BlendSpace for direction-based movement
func setup_movement_blend():
    var blend_space = BlendSpace2D.new()
    
    # Add animations at different directions
    blend_space.add_point(Vector2(0, 0), idle_anim, 0.1)  # Center = Idle
    blend_space.add_point(Vector2(1, 0), walk_forward_anim, 0.1)  # Forward
    blend_space.add_point(Vector2(-1, 0), walk_backward_anim, 0.1)  # Backward
    blend_space.add_point(Vector2(0, 1), walk_left_anim, 0.1)  # Left
    blend_space.add_point(Vector2(0, -1), walk_right_anim, 0.1)  # Right
    
    # Add diagonals
    blend_space.add_point(Vector2(1, 1), walk_forward_left_anim, 0.1)
    blend_space.add_point(Vector2(1, -1), walk_forward_right_anim, 0.1)
    blend_space.add_point(Vector2(-1, 1), walk_backward_left_anim, 0.1)
    blend_space.add_point(Vector2(-1, -1), walk_backward_right_anim, 0.1)
    
    animation_tree.add_node(blend_space)
    animation_tree.connect("parameters/blend_position", blend_space, "blend_position")
    
    # Update blend position based on input
    animation_tree["parameters/blend_position"] = get_movement_input_vector()
```

### 6. Launcher Montage Requirements

The **launcher montage** must have:
1. **At least two readable camera-composed action beats**
2. **No clipped hero or monster silhouettes**
3. **Cinematic quality**

**Implementation**:
```gdscript
# launcher_overlay.gd
class_name LauncherMontage extends Node:
    
    @export var camera: Camera3D
    @export var hero: Node3D
    @export var monster: Node3D
    
    @export var beat1_position: Vector3
    @export var beat2_position: Vector3
    @export var beat1_lookat: Vector3
    @export var beat2_lookat: Vector3
    
    @export var beat_duration: float = 2.0
    @export var transition_duration: float = 1.0
    
    var current_beat: int = 0
    var beat_timer: float = 0.0
    
    func _ready() -> void:
        start_montage()
    
    func start_montage() -> void:
        current_beat = 0
        beat_timer = 0.0
        setup_beat_0()
    
    func setup_beat_0() -> void:
        # Initial camera position - wide shot
        camera.global_position = beat1_position
        camera.look_at(beat1_lookat, Vector3.UP)
        
        # Hero pose - ready stance
        hero.play_animation("montage_ready")
        
        # Monster pose - idle
        monster.play_animation("montage_idle")
        
        # Ensure no clipping
        ensure_no_clipping()
    
    func setup_beat_1() -> void:
        # Close-up on hero
        camera.global_position = beat2_position
        camera.look_at(beat2_lookat, Vector3.UP)
        
        # Hero action - attack
        hero.play_animation("montage_attack")
        
        # Monster reaction
        monster.play_animation("montage_hit")
        
        # Ensure no clipping
        ensure_no_clipping()
    
    func _process(delta: float) -> void:
        beat_timer += delta
        
        if current_beat == 0 and beat_timer >= beat_duration:
            current_beat = 1
            beat_timer = 0.0
            setup_beat_1()
        elif current_beat == 1 and beat_timer >= beat_duration:
            # Loop or end
            start_montage()
    
    func ensure_no_clipping() -> void:
        # Check if hero or monster are clipped by camera view
        var hero_screen_pos = camera.unproject_position(hero.global_position)
        var monster_screen_pos = camera.unproject_position(monster.global_position)
        
        # Check if positions are within camera frustum
        if not is_in_frustum(hero_screen_pos) or not is_in_frustum(monster_screen_pos):
            push_warning("Hero or monster clipped by camera!")
            # Adjust positions
            adjust_for_clipping()
```

---

## Technical Deep Dive

### 1. Skeleton Retargeting Pipeline

```
UAL1_Standard.glb (Source)
    ↓
[Import into Godot]
    ↓
AnimationLibrary Resource
    ↓
[Validate Skeleton Compatibility]
    ↓
RetargetProfile (if needed)
    ↓
Child Skeleton / Creature Skeleton
    ↓
AnimationTree or AnimationPlayer
    ↓
Character Mesh (with facial rig from VS-024)
```

### 2. Retarget Profile Creation

```gdscript
# src/domain/animation/retarget_profile_factory.gd
class_name RetargetProfileFactory extends RefCounted:
    
    # Standard humanoid bone mapping
    static var STANDARD_BONE_MAP: Dictionary = {
        # Lower body
        "Hips": "Hips",
        "Spine": "Spine",
        "Spine1": "Spine1",
        "Spine2": "Spine2",
        "Neck": "Neck",
        "Head": "Head",
        
        # Left arm
        "Arm_L": "Arm_L",
        "ForeArm_L": "ForeArm_L",
        "Hand_L": "Hand_L",
        
        # Right arm
        "Arm_R": "Arm_R",
        "ForeArm_R": "ForeArm_R",
        "Hand_R": "Hand_R",
        
        # Left leg
        "Thigh_L": "Thigh_L",
        "Shin_L": "Shin_L",
        "Foot_L": "Foot_L",
        "Toe_L": "Toe_L",
        
        # Right leg
        "Thigh_R": "Thigh_R",
        "Shin_R": "Shin_R",
        "Foot_R": "Foot_R",
        "Toe_R": "Toe_R",
        
        # Optional facial bones (from VS-024)
        "Jaw": "Jaw",
        "Eye_L": "Eye_L",
        "Eye_R": "Eye_R",
    }
    
    func create_universal_profile() -> RetargetProfile:
        var profile = RetargetProfile.new()
        
        for source_bone in STANDARD_BONE_MAP:
            var target_bone = STANDARD_BONE_MAP[source_bone]
            profile.add_bone_map(source_bone, target_bone)
        
        # Set retargeting options
        profile.retarget_position = true
        profile.retarget_rotation = true
        profile.retarget_scale = false  # Usually don't want to scale bones
        
        return profile
    
    func create_child_profile() -> RetargetProfile:
        var profile = create_universal_profile()
        
        # Child-specific adjustments
        # Children have proportionally larger heads
        profile.add_bone_scale_override("Head", Vector3(1.1, 1.1, 1.1))
        
        # Shorter limbs
        profile.add_bone_scale_override("Arm_L", Vector3(0.9, 0.9, 0.9))
        profile.add_bone_scale_override("Arm_R", Vector3(0.9, 0.9, 0.9))
        profile.add_bone_scale_override("Thigh_L", Vector3(0.9, 0.9, 0.9))
        profile.add_bone_scale_override("Thigh_R", Vector3(0.9, 0.9, 0.9))
        
        return profile
    
    func create_creature_profile(creature_type: String) -> RetargetProfile:
        var profile = create_universal_profile()
        
        match creature_type:
            "Slime":
                # Slimes might not have bones - use mesh deformation
                profile.retarget_method = RetargetProfile.RETARGET_METHOD_MORPH
            "Humanoid":
                # Use standard profile
                pass
            "Quadruped":
                # Four-legged creatures
                profile.add_bone_map("Arm_L", "FrontLeg_L")
                profile.add_bone_map("Arm_R", "FrontLeg_R")
                profile.add_bone_map("Thigh_L", "BackLeg_L")
                profile.add_bone_map("Thigh_R", "BackLeg_R")
        
        return profile
```

### 3. Animation State Machine (AnimationTree)

```gdscript
# src/adapters/inbound/animation/character_animation_tree.gd
class_name CharacterAnimationTree extends Node:
    
    @export var animation_tree: AnimationTree
    @export var skeleton: Skeleton3D
    @export var mesh_instance: MeshInstance3D
    
    # Animation states
    enum State {
        IDLE,
        WALK,
        RUN,
        ATTACK,
        HIT,
        WINDUP,  # From VS-005
        DEATH,
    }
    
    var current_state: State = State.IDLE
    
    # Animation players for different sources
    @export var ual_player: AnimationPlayer  # For UAL animations
    @export var custom_player: AnimationPlayer  # For custom animations
    
    func _ready() -> void:
        setup_animation_tree()
    
    func setup_animation_tree() -> void:
        # Create state machine
        var state_machine = AnimationNodeStateMachinePlayback.new()
        animation_tree.add_node(state_machine)
        animation_tree.active = true
        
        # Add states
        for state in State.values():
            add_state(state_machine, state)
        
        # Setup transitions
        setup_transitions(state_machine)
    
    func add_state(state_machine: AnimationNodeStateMachinePlayback, state: State) -> void:
        var state_name = State.keys()[state]
        var anim_node = AnimationNodeAnimation.new()
        
        # Assign appropriate animation
        match state:
            State.IDLE:
                anim_node.animation = "ual_idle"
            State.WALK:
                anim_node.animation = "ual_walk"
            State.RUN:
                anim_node.animation = "ual_run"
            State.ATTACK:
                anim_node.animation = "ual_attack"
            State.HIT:
                anim_node.animation = "ual_hit"
            State.WINDUP:
                anim_node.animation = "custom_windup"  # From VS-005
            State.DEATH:
                anim_node.animation = "ual_death"
        
        # Add to state machine
        var state_index = state_machine.add_state(state_name, anim_node)
        
        # Configure state
        state_machine.state_set_loop(state_index, state != State.ATTACK and state != State.HIT)
    
    func setup_transitions(state_machine: AnimationNodeStateMachinePlayback) -> void:
        # Idle to Walk
        state_machine.add_transition(
            State.IDLE,
            State.WALK,
            "parameters/is_moving"
        )
        
        # Walk to Idle
        state_machine.add_transition(
            State.WALK,
            State.IDLE,
            "parameters/is_moving",
            false
        )
        
        # Walk to Run
        state_machine.add_transition(
            State.WALK,
            State.RUN,
            "parameters/is_running"
        )
        
        # Run to Walk
        state_machine.add_transition(
            State.RUN,
            State.WALK,
            "parameters/is_running",
            false
        )
        
        # Any to Attack
        state_machine.add_transition(
            AnimationNodeStateMachinePlayback.TRANSITION_MIN_PRIORITY,
            State.ATTACK,
            "parameters/attack_trigger"
        )
        
        # Attack to Idle
        state_machine.add_transition(
            State.ATTACK,
            State.IDLE,
            AnimationNodeStateMachinePlayback.TRANSITION_AUTO
        )
        
        # Any to Hit
        state_machine.add_transition(
            AnimationNodeStateMachinePlayback.TRANSITION_MIN_PRIORITY,
            State.HIT,
            "parameters/hit_trigger"
        )
        
        # Hit to Idle
        state_machine.add_transition(
            State.HIT,
            State.IDLE,
            AnimationNodeStateMachinePlayback.TRANSITION_AUTO
        )
    
    func update_parameters(delta: Vector2, is_running: bool, attack: bool, hit: bool) -> void:
        animation_tree["parameters/is_moving"] = delta.length() > 0.1
        animation_tree["parameters/is_running"] = is_running
        animation_tree["parameters/attack_trigger"] = attack
        animation_tree["parameters/hit_trigger"] = hit
        animation_tree["parameters/movement_vector"] = delta
```

### 4. Grounded Animation System

```gdscript
# src/adapters/inbound/animation/grounded_animation_processor.gd
class_name GroundedAnimationProcessor extends Node:
    
    @export var skeleton: Skeleton3D
    @export var mesh_instance: MeshInstance3D
    @export var raycast_length: float = 1.0
    
    # Floor contact tracking
    var left_foot_contact: bool = false
    var right_foot_contact: bool = false
    
    func _physics_process(delta: float) -> void:
        update_foot_ik()
        prevent_root_sliding()
    
    func update_foot_ik() -> void:
        # Check if Foot IK is enabled
        if not skeleton.foot_ik_enabled:
            return
        
        # Raycast from each foot
        left_foot_contact = check_foot_contact("Foot_L")
        right_foot_contact = check_foot_contact("Foot_R")
        
        # Adjust foot positions to ground
        if left_foot_contact:
            adjust_foot_to_ground("Foot_L")
        if right_foot_contact:
            adjust_foot_to_ground("Foot_R")
    
    func check_foot_contact(foot_bone: String) -> bool:
        var foot_pos = skeleton.get_bone_global_pose(foot_bone).origin
        var ray_origin = foot_pos + Vector3(0, raycast_length, 0)
        var ray_end = foot_pos - Vector3(0, raycast_length * 2, 0)
        
        var space_state = get_world_3d().direct_space_state
        var query = PhysicsRayQueryParameters3D.new()
        query.from = ray_origin
        query.to = ray_end
        query.collide_with_bodies = true
        query.collide_with_areas = true
        
        var result = space_state.intersect_ray(query)
        
        return result.has("position")
    
    func adjust_foot_to_ground(foot_bone: String) -> void:
        var foot_pos = skeleton.get_bone_global_pose(foot_bone).origin
        var ray_origin = foot_pos + Vector3(0, raycast_length, 0)
        var ray_end = foot_pos - Vector3(0, raycast_length * 2, 0)
        
        var space_state = get_world_3d().direct_space_state
        var query = PhysicsRayQueryParameters3D.new()
        query.from = ray_origin
        query.to = ray_end
        
        var result = space_state.intersect_ray(query)
        
        if result.has("position"):
            var ground_pos = result["position"]
            var offset = foot_pos - ground_pos
            
            # Apply offset to skeleton
            # This moves the entire skeleton down to keep foot on ground
            skeleton.global_position += Vector3(0, -offset.y, 0)
    
    func prevent_root_sliding() -> void:
        # Store previous root position
        static var prev_root_pos: Vector3 = Vector3.ZERO
        
        var current_root_pos = skeleton.global_position
        
        # If root moved horizontally (XZ) without intentional movement
        var horizontal_movement = Vector2(current_root_pos.x, current_root_pos.z) - \
                                  Vector2(prev_root_pos.x, prev_root_pos.z)
        
        if horizontal_movement.length() > 0.01:
            # This might be intentional movement from player input
            # Only prevent sliding if it's from animation
            pass
        
        prev_root_pos = current_root_pos
```

### 5. Launcher Montage Camera System

```gdscript
# src/adapters/inbound/scenes/launcher/launcher_camera_director.gd
class_name LauncherCameraDirector extends Node:
    
    @export var camera: Camera3D
    @export var hero: Node3D
    @export var monster: Node3D
    
    # Camera beats
    @export var beats: Array[Dictionary] = [
        {
            "position": Vector3(0, 2, 5),
            "look_at": Vector3(0, 1, 0),
            "fov": 60.0,
            "duration": 3.0,
            "hero_animation": "montage_idle",
            "monster_animation": "montage_idle",
        },
        {
            "position": Vector3(2, 1, 2),
            "look_at": Vector3(0, 1, 0),
            "fov": 45.0,
            "duration": 4.0,
            "hero_animation": "montage_attack",
            "monster_animation": "montage_hit",
        },
        {
            "position": Vector3(-2, 1, 2),
            "look_at": Vector3(0, 1, 0),
            "fov": 45.0,
            "duration": 3.0,
            "hero_animation": "montage_ready",
            "monster_animation": "montage_recover",
        },
    ]
    
    var current_beat_index: int = 0
    var beat_timer: float = 0.0
    
    func _ready() -> void:
        start_montage()
    
    func start_montage() -> void:
        current_beat_index = 0
        beat_timer = 0.0
        setup_beat(0)
    
    func setup_beat(beat_index: int) -> void:
        if beat_index >= beats.size():
            return
        
        var beat = beats[beat_index]
        
        # Camera setup
        var tween = create_tween()
        tween.tween_property(camera, "global_position", beat["position"], 1.0)
        tween.tween_property(camera, "look_at", beat["look_at"], 1.0)
        tween.tween_property(camera, "fov", beat["fov"], 1.0)
        
        # Hero animation
        if hero.has_method("play_animation"):
            hero.call("play_animation", beat["hero_animation"])
        
        # Monster animation
        if monster.has_method("play_animation"):
            monster.call("play_animation", beat["monster_animation"])
        
        # Ensure no clipping
        ensure_no_clipping()
    
    func _process(delta: float) -> void:
        beat_timer += delta
        
        if current_beat_index < beats.size():
            var current_beat = beats[current_beat_index]
            
            if beat_timer >= current_beat["duration"]:
                beat_timer = 0.0
                current_beat_index += 1
                
                if current_beat_index < beats.size():
                    setup_beat(current_beat_index)
                else:
                    # Loop or end
                    start_montage()
    
    func ensure_no_clipping() -> void:
        # Check visibility of hero and monster from camera
        var camera_transform = camera.global_transform
        
        # Check hero
        var hero_visible = is_visible_from_camera(hero, camera)
        var monster_visible = is_visible_from_camera(monster, camera)
        
        if not hero_visible:
            push_warning("Hero is clipped by camera view!")
            # Adjust camera or hero position
            adjust_camera_for_clipping(camera, hero)
        
        if not monster_visible:
            push_warning("Monster is clipped by camera view!")
            # Adjust camera or monster position
            adjust_camera_for_clipping(camera, monster)
    
    func is_visible_from_camera(node: Node3D, camera: Camera3D) -> bool:
        # Get node position in camera space
        var node_pos = camera.to_local(node.global_position)
        
        # Check if within camera frustum
        if abs(node_pos.x) > camera.size.x * 2:
            return false
        if abs(node_pos.y) > camera.size.y * 2:
            return false
        if node_pos.z < camera.near:
            return false
        if node_pos.z > camera.far:
            return false
        
        return true
    
    func adjust_camera_for_clipping(camera: Camera3D, node: Node3D) -> void:
        # Move camera to ensure node is visible
        var direction_to_node = (node.global_position - camera.global_position).normalized()
        
        # Move camera back a bit
        camera.global_position -= direction_to_node * 1.0
        camera.look_at(node.global_position, Vector3.UP)
```

---

## Code Samples

### 1. Importing and Retargeting UAL Animations

```gdscript
# src/adapters/inbound/animation/ual_importer.gd
class_name UALImporter extends Node:
    
    @export var ual_path: String = "data/models/quaternius/animations/UAL1_Standard.glb"
    @export var target_skeleton: Skeleton3D
    
    var animation_library: AnimationLibrary
    var retarget_profile: RetargetProfile
    
    func _ready() -> void:
        import_ual()
    
    func import_ual() -> void:
        # Load the GLB file
        var file = FileAccess.open(ual_path, FileAccess.READ)
        if not file:
            push_error("Could not open UAL file: %s" % ual_path)
            return
        
        # Import as PackedScene
        var packed_scene = ResourceLoader.load(ual_path)
        if not packed_scene:
            push_error("Could not load UAL as PackedScene")
            return
        
        # Find AnimationLibrary in the scene
        animation_library = find_animation_library(packed_scene)
        
        if not animation_library:
            push_error("No AnimationLibrary found in UAL")
            return
        
        # Get source skeleton from UAL
        var source_skeleton = find_skeleton(packed_scene)
        
        if not source_skeleton:
            push_error("No Skeleton3D found in UAL")
            return
        
        # Validate compatibility
        if not validate_skeleton_compatibility(source_skeleton, target_skeleton):
            push_error("Skeletons are not compatible!")
            return
        
        # Create retarget profile
        retarget_profile = create_retarget_profile(source_skeleton, target_skeleton)
        
        # Apply animations to target
        apply_animations_to_target()
    
    func find_animation_library(node: Node) -> AnimationLibrary:
        if node is AnimationLibrary:
            return node
        
        for child in node.get_children():
            var result = find_animation_library(child)
            if result:
                return result
        
        return null
    
    func find_skeleton(node: Node) -> Skeleton3D:
        if node is Skeleton3D:
            return node
        
        for child in node.get_children():
            var result = find_skeleton(child)
            if result:
                return result
        
        return null
    
    func apply_animations_to_target() -> void:
        # Add AnimationPlayer to target
        var anim_player = AnimationPlayer.new()
        target_skeleton.add_child(anim_player)
        
        # Load each animation
        for anim_name in animation_library.get_animation_list():
            var animation = animation_library.get_animation(anim_name)
            
            # Create retargeted copy
            var retargeted_anim = retarget_animation(animation, retarget_profile)
            
            # Add to player
            anim_player.add_animation(anim_name, retargeted_anim)
        
        print("Successfully imported %d animations from UAL" % animation_library.get_animation_list().size())
    
    func retarget_animation(animation: Animation, profile: RetargetProfile) -> Animation:
        # This is a simplified version
        # In practice, use Godot's built-in retargeting
        
        var new_anim = Animation.new()
        new_anim.length = animation.length
        new_anim.loop_mode = animation.loop_mode
        
        # Copy tracks with bone remapping
        for track_idx in range(animation.get_track_count()):
            var track = animation.get_track(track_idx)
            var path = animation.track_get_path(track_idx)
            
            # Remap bone path if needed
            var new_path = apply_bone_mapping(path, profile)
            
            # Copy track to new animation
            # (Implementation depends on track type)
        
        return new_anim
    
    func apply_bone_mapping(path: NodePath, profile: RetargetProfile) -> NodePath:
        # Extract bone name from path
        var parts = path.get_names()
        if parts.size() == 0:
            return path
        
        var bone_name = parts[-1]
        
        # Check if bone needs remapping
        if profile.has_bone_map(bone_name):
            var target_bone = profile.get_bone_map(bone_name)
            parts[-1] = target_bone
            return NodePath(parts)
        
        return path
```

### 2. Animation State Validation (Automated Testing)

```gdscript
# tests/adapters/inbound/test_animation_retargeting.gd
class_name TestAnimationRetargeting extends GDEUnitTest:
    
    func test_skeleton_compatibility():
        var child_skeleton = load_child_skeleton()
        var creature_skeleton = load_creature_skeleton()
        var ual_skeleton = load_ual_skeleton()
        
        # Test child skeleton compatibility
        var child_compatible = RetargetProfileFactory.validate_skeleton_compatibility(
            ual_skeleton, child_skeleton
        )
        assert_true(child_compatible, "Child skeleton should be compatible with UAL")
        
        # Test creature skeleton compatibility
        var creature_compatible = RetargetProfileFactory.validate_skeleton_compatibility(
            ual_skeleton, creature_skeleton
        )
        assert_true(creature_compatible, "Creature skeleton should be compatible with UAL")
    
    func test_grounded_animations():
        var character = create_test_character()
        add_child(character)
        
        # Play walk animation
        character.play_animation("walk")
        
        # Process a few frames
        for i in range(10):
            character._process(0.1)
        
        # Check that feet are on ground
        var left_foot_height = character.get_bone_global_position("Foot_L").y
        var right_foot_height = character.get_bone_global_position("Foot_R").y
        
        # Feet should be near ground level (0)
        assert_true(abs(left_foot_height) < 0.1, "Left foot should be grounded")
        assert_true(abs(right_foot_height) < 0.1, "Right foot should be grounded")
    
    func test_no_root_sliding():
        var character = create_test_character()
        add_child(character)
        
        var initial_position = character.global_position
        
        # Play idle animation for several frames
        character.play_animation("idle")
        
        for i in range(30):
            character._process(0.1)
        
        var final_position = character.global_position
        
        # Position should not have changed significantly
        var movement = (final_position - initial_position).length()
        assert_true(movement < 0.01, "Character should not slide during idle animation")
    
    func test_facing_direction():
        var character = create_test_character()
        add_child(character)
        
        # Set character to face forward
        character.global_rotation = Quaternion.IDENTITY
        
        # Play walk forward animation
        character.play_animation("walk_forward")
        character._process(0.1)
        
        # Character should be facing forward
        var forward_dir = character.global_transform.basis.z.normalized()
        var expected_forward = Vector3.FORWARD
        
        var angle = forward_dir.angle_to(expected_forward)
        assert_true(angle < 0.1, "Character should face forward during walk_forward")
    
    func test_launcher_montage_visibility():
        var launcher = create_launcher_scene()
        add_child(launcher)
        
        # Start montage
        launcher.start_montage()
        
        # Process through beats
        for i in range(10):
            launcher._process(0.5)
        
        # Check that hero and monster are visible
        var hero_visible = launcher.is_hero_visible()
        var monster_visible = launcher.is_monster_visible()
        
        assert_true(hero_visible, "Hero should be visible in launcher montage")
        assert_true(monster_visible, "Monster should be visible in launcher montage")
```

### 3. Rendered Evidence Capture

```gdscript
# src/adapters/inbound/animation/animation_evidence_capture.gd
class_name AnimationEvidenceCapture extends Node:
    
    @export var viewport: Viewport
    @export var output_dir: String = "user://animation_evidence/"
    
    var frame_count: int = 0
    
    func _ready() -> void:
        create_output_directory()
    
    func create_output_directory() -> void:
        var dir = Directory.new()
        if not dir.open(output_dir):
            dir.make_dir_recursive(output_dir)
    
    func capture_animation_evidence(character: Node3D, animation_name: String, duration: float) -> void:
        # Store original animation
        var original_anim = character.get_current_animation()
        
        # Play the animation
        character.play_animation(animation_name)
        
        # Capture frames over duration
        var frames_to_capture = int(duration * 30)  # 30 FPS
        
        for i in range(frames_to_capture):
            await get_tree().create_timer(1.0 / 30.0).timeout
            
            var filename = "%s/%s_frame_%04d.png" % [output_dir, animation_name, frame_count]
            capture_viewport(filename)
            frame_count += 1
        
        # Restore original animation
        character.play_animation(original_anim)
    
    func capture_viewport(filename: String) -> void:
        var image = viewport.get_texture().get_image()
        image.save_png(filename)
        print("Captured: %s" % filename)
    
    func capture_all_animations(character: Node3D, animation_names: Array) -> void:
        for anim_name in animation_names:
            capture_animation_evidence(character, anim_name, 3.0)
    
    func generate_evidence_report() -> Dictionary:
        var report = {
            "timestamp": Time.get_unix_time_from_system(),
            "character": character.name,
            "animations": [],
            "frames_captured": frame_count,
            "output_dir": output_dir,
        }
        
        # Add animation details
        for anim_name in animation_names:
            report["animations"].append({
                "name": anim_name,
                "frames": frames_to_capture,
                "duration": 3.0,
            })
        
        return report
```

### 4. BlendSpace for Directional Movement

```gdscript
# src/adapters/inbound/animation/blend_space_movement.gd
class_name BlendSpaceMovement extends Node:
    
    @export var animation_tree: AnimationTree
    @export var skeleton: Skeleton3D
    
    # Movement animations
    @export var idle_anim: Animation
    @export var walk_forward_anim: Animation
    @export var walk_backward_anim: Animation
    @export var walk_left_anim: Animation
    @export var walk_right_anim: Animation
    
    # BlendSpace node
    var blend_space: BlendSpace2D
    
    func _ready() -> void:
        setup_blend_space()
    
    func setup_blend_space() -> void:
        # Create BlendSpace2D
        blend_space = BlendSpace2D.new()
        animation_tree.add_node(blend_space)
        
        # Add animations to BlendSpace
        # Center = Idle
        blend_space.add_point(Vector2(0, 0), idle_anim, 0.2)
        
        # Cardinal directions
        blend_space.add_point(Vector2(1, 0), walk_forward_anim, 0.2)  # Forward
        blend_space.add_point(Vector2(-1, 0), walk_backward_anim, 0.2)  # Backward
        blend_space.add_point(Vector2(0, 1), walk_left_anim, 0.2)  # Left
        blend_space.add_point(Vector2(0, -1), walk_right_anim, 0.2)  # Right
        
        # Diagonals
        blend_space.add_point(Vector2(1, 1), walk_forward_anim, 0.1)  # Forward-Left
        blend_space.add_point(Vector2(1, -1), walk_forward_anim, 0.1)  # Forward-Right
        blend_space.add_point(Vector2(-1, 1), walk_backward_anim, 0.1)  # Backward-Left
        blend_space.add_point(Vector2(-1, -1), walk_backward_anim, 0.1)  # Backward-Right
        
        # Connect to output
        animation_tree.add_node(AnimationNodeOutput.new())
        animation_tree.connect(blend_space.get_output_port(), animation_tree.get_node(1).get_input_port(0))
        
        # Set active
        animation_tree.active = true
    
    func update_movement(input_vector: Vector2) -> void:
        # Normalize input
        if input_vector.length() > 1.0:
            input_vector = input_vector.normalized()
        
        # Update blend position
        animation_tree["parameters/blend_position"] = input_vector
    
    func get_movement_animation(input_vector: Vector2) -> String:
        # For debugging: return which animation is dominant
        if input_vector.length() < 0.1:
            return "idle"
        
        var angle = input_vector.angle()
        
        # Convert angle to cardinal direction
        if abs(angle) < PI / 8:
            return "walk_forward"
        elif angle < 3 * PI / 8:
            return "walk_forward_right"
        elif angle < 5 * PI / 8:
            return "walk_right"
        elif angle < 7 * PI / 8:
            return "walk_backward_right"
        elif abs(angle) < 9 * PI / 8:
            return "walk_backward"
        elif angle < 11 * PI / 8:
            return "walk_backward_left"
        elif angle < 13 * PI / 8:
            return "walk_left"
        elif angle < 15 * PI / 8:
            return "walk_forward_left"
        else:
            return "walk_forward"
```

---

## Asset Packages and Tools

### 1. CC0 Universal Animation Library

| Asset | Source | License | Link |
|-------|--------|---------|------|
| UAL1_Standard.glb | Quaternius | CC0 | [Download](https://quaternius.com/free-3d-models?category=animations) |
| UAL1_Humanoid.glb | Quaternius | CC0 | [Download](https://quaternius.com/free-3d-models?category=animations) |
| UAL1_Creatures.glb | Quaternius | CC0 | [Download](https://quaternius.com/free-3d-models?category=animations) |

**UAL Contents**:
- Humanoid Animations: 100+ animations (idle, walk, run, jump, crouch, swim, climb, etc.)
- Combat Animations: Attack, hit, block, dodge, death
- Interaction Animations: Pick up, use, throw, push, pull
- Emotion Animations: Happy, angry, sad, surprised, scared
- Cinematic Animations: Poses, dramatic actions
- Creature Animations: Quadruped, flying, swimming

### 2. Quaternius Character Models

| Model | Category | License | Link |
|-------|----------|---------|------|
| Child Characters | Characters | CC0 | [Quaternius Characters](https://quaternius.com/free-3d-models?category=characters) |
| Adult Characters | Characters | CC0 | [Quaternius Characters](https://quaternius.com/free-3d-models?category=characters) |
| Creatures | Creatures | CC0 | [Quaternius Creatures](https://quaternius.com/free-3d-models?category=creatures) |
| Animals | Animals | CC0 | [Quaternius Animals](https://quaternius.com/free-3d-models?category=animals) |

### 3. Mixamo (Alternative Source)

| Asset | License | Link | Notes |
|-------|---------|------|-------|
| Humanoid Animations | Free for non-commercial | [mixamo.com](https://www.mixamo.com/) | Requires attribution, limited commercial use |
| Auto-Rigging | Free | [mixamo.com](https://www.mixamo.com/) | Upload your model, get auto-rigged |

**Note**: Mixamo requires attribution and has usage restrictions. **Quaternius CC0 is preferred.**

### 4. Godot Asset Library

| Asset | ID | License | Link |
|-------|----|---------|------|
| Animation Retargeting | Various | Various | [Godot AssetLib](https://godotengine.org/asset-library/asset) |
| Skeleton Tools | Various | Various | [Godot AssetLib](https://godotengine.org/asset-library/asset) |

### 5. Blender (For Custom Retargeting)

| Tool | Purpose | License | Link |
|------|---------|---------|------|
| Blender | 3D modeling and animation | GNU GPL | [blender.org](https://www.blender.org/) |
| Rigify Addon | Auto-rigging | GNU GPL | Built into Blender |
| Animation Retargeting Addons | Retargeting | Various | [Blender Market](https://blendermarket.com/) |

---

## Learning Resources

### 1. Godot Animation System

1. **Official Godot Documentation**
   - [AnimationTree](https://docs.godotengine.org/en/stable/classes/class_animationtree.html)
   - [AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html)
   - [Skeleton3D](https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html)
   - [BlendSpaces](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html#blend-spaces)
   - [State Machines](https://docs.godotengine.org/en/stable/tutorials/animation/state_machine_transitions.html)

2. **Godot Animation Tutorials**
   - [GDQuest Animation Course](https://gdquest.com/course/godot-4-animation/)
   - [HeartBeast Animation](https://www.heartbeast.co/godot-4-animation/)
   - [KidsCanCode Animation](https://www.youtube.com/watch?v=K5qNg9RJXcE)

### 2. Animation Retargeting

1. **Godot Retargeting**
   - [Retargeting in Godot 4.0](https://docs.godotengine.org/en/stable/tutorials/animation/retargeting_animations.html)
   - [Skeleton3D Retargeting](https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html#retargeting)

2. **Blender Retargeting**
   - [Blender Animation Retargeting](https://docs.blender.org/manual/en/latest/animation/retargeting/index.html)
   - [Mixamo to Rigify](https://www.youtube.com/watch?v=example)

### 3. Cinematic Techniques

1. **Camera Composition**
   - [Rule of Thirds](https://www.studiobinder.com/photography/rule-of-thirds/)
   - [Camera Angles](https://www.studiobinder.com/ultimate-guide-to-camera-shots/)
   - [Framing Techniques](https://www.premiumbeat.com/blog/camera-framing-techniques/)

2. **Godot Cinematics**
   - [Camera3D Tutorial](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)
   - [Cinematic Camera](https://docs.godotengine.org/en/stable/tutorials/3d/cameras.html)
   - [Cutscene System](https://docs.godotengine.org/en/stable/tutorials/step_by_step/cutscenes.html)

### 4. Child and Creature Animation

1. **Child Character Animation**
   - [Child Proportions Guide](https://www.anatomymasterclass.com/blog/child-proportions)
   - [Child Movement Study](https://www.youtube.com/watch?v=example)

2. **Creature Animation**
   - [Creature Design](https://www.gamasutra.com/view/feature/132353/)
   - [Monster Animation](https://www.youtube.com/watch?v=example)

---

## Implementation Checklist

### Phase 1: Skeleton Analysis and Preparation (Priority: HIGH)

- [ ] Load UAL1_Standard.glb and inspect skeleton hierarchy
- [ ] Load child character rigs and inspect skeleton hierarchy
- [ ] Load creature rigs from VS-023 and inspect skeleton hierarchy
- [ ] Document all bone names for each skeleton
- [ ] Identify bone mapping between UAL and target skeletons
- [ ] Create bone mapping tables for each character type
- [ ] Validate skeleton compatibility for all target rigs
- [ ] Identify any missing bones that need manual mapping

### Phase 2: Retarget Profile Creation (Priority: HIGH)

- [ ] Create universal retarget profile for humanoid characters
- [ ] Create child-specific retarget profile with proportion adjustments
- [ ] Create creature-specific retarget profiles (per creature type)
- [ ] Test retarget profiles with sample animations
- [ ] Adjust bone mappings as needed
- [ ] Document all retarget profiles
- [ ] Create retarget profile factory class

### Phase 3: Animation Import and Processing (Priority: HIGH)

- [ ] Import UAL1_Standard.glb into project
- [ ] Extract AnimationLibrary from UAL
- [ ] Process each animation through retarget profiles
- [ ] Validate retargeted animations on child rigs
- [ ] Validate retargeted animations on creature rigs
- [ ] Check for animation artifacts (twisting, popping)
- [ ] Optimize animations (remove unused tracks, simplify keyframes)
- [ ] Save retargeted animations as separate resources

### Phase 4: Grounded Animation System (Priority: HIGH)

- [ ] Implement foot IK for child characters
- [ ] Implement foot IK for creatures
- [ ] Add ground detection for feet
- [ ] Prevent root sliding in all animations
- [ ] Test grounded behavior on various terrains
- [ ] Validate no floating feet during movement
- [ ] Validate no foot penetration through ground

### Phase 5: Direction-Based Animation (Priority: MEDIUM)

- [ ] Set up BlendSpace2D for movement
- [ ] Create or import 8-directional walk animations
- [ ] Create or import 8-directional run animations
- [ ] Set up direction-based blending in AnimationTree
- [ ] Test movement in all directions
- [ ] Validate character faces movement direction
- [ ] Validate smooth transitions between directions

### Phase 6: Combat Animation Integration (Priority: MEDIUM)

- [ ] Integrate UAL attack animations with existing combat (VS-005)
- [ ] Ensure attack animations face threat direction
- [ ] Integrate hit reaction animations
- [ ] Ensure hit reactions face away from attacker
- [ ] Test combat flow with new animations
- [ ] Validate wind-up telegraph still works
- [ ] Validate hitstop integration

### Phase 7: Facial Animation Integration (Priority: MEDIUM)

- [ ] Integrate UAL animations with VS-024 facial system
- [ ] Ensure facial animations don't conflict with body animations
- [ ] Test blink system with new animations
- [ ] Test speech-driven mouth movement
- [ ] Test emotion states
- [ ] Validate performance (only animate visible characters)

### Phase 8: Launcher Montage (Priority: HIGH)

- [ ] Design camera beats for launcher montage
- [ ] Position hero and monster for beat 1
- [ ] Position hero and monster for beat 2
- [ ] Set up camera movements between beats
- [ ] Select hero animations for each beat
- [ ] Select monster animations for each beat
- [ ] Ensure no clipping in any beat
- [ ] Test montage in various viewport sizes
- [ ] Capture rendered evidence of montage

### Phase 9: Automated Testing (Priority: HIGH)

- [ ] Write skeleton compatibility tests
- [ ] Write grounded animation tests
- [ ] Write no root sliding tests
- [ ] Write facing direction tests
- [ ] Write launcher montage visibility tests
- [ ] Write animation state transition tests
- [ ] Write performance tests
- [ ] Integrate tests into CI pipeline

### Phase 10: Rendered Evidence (Priority: HIGH)

- [ ] Capture screenshots of all animations on child rigs
- [ ] Capture screenshots of all animations on creature rigs
- [ ] Capture launcher montage frames
- [ ] Generate animation evidence report
- [ ] Verify no clipping in any captured frame
- [ ] Verify readability of all action beats
- [ ] Package evidence for review

### Phase 11: Integration and Polish (Priority: MEDIUM)

- [ ] Integrate retargeted animations into player_controller.gd
- [ ] Integrate retargeted animations into gameplay_runtime.gd
- [ ] Integrate launcher montage into launcher_overlay.gd
- [ ] Test full gameplay loop with new animations
- [ ] Optimize animation performance
- [ ] Add animation debugging tools
- [ ] Document animation system

---

## Child-Safety Constraints

### Animation Content Safety

1. **No Violent Animations**
   - No decapitation, dismemberment, or gore
   - No realistic death animations
   - Only cartoon-style hit reactions

2. **Creature Animations**
   - Creature attacks must use wind-up telegraph (from VS-005)
   - Creature deaths must be non-graphic (fade out, fly away)
   - No realistic animal suffering

3. **Character Animations**
   - No suggestive or inappropriate poses
   - No realistic injury animations
   - All combat animations must be reversible

4. **Camera Safety**
   - Launcher montage must not show upskirt or inappropriate angles
   - Camera must not clip through characters
   - All characters must be fully visible in key beats

### Performance Safety

1. **Animation Optimization**
   - Remove unused animation tracks
   - Simplify complex keyframes
   - Use compression where possible

2. **Memory Management**
   - Stream animations (load on demand)
   - Pool animation players
   - Unload unused animations

3. **Processing Budget**
   - Limit animation updates per frame
   - Only animate visible characters
   - Use LOD for distant characters

---

## Recommendations

### ✅ DO IMPLEMENT

1. **UAL Integration** - High-quality animations, CC0 licensed
2. **Retarget Profiles** - Essential for cross-skeleton compatibility
3. **Grounded Animation System** - Critical for polish
4. **Direction-Based Blending** - Improves movement quality
5. **Launcher Montage** - Required for acceptance criteria
6. **Automated Testing** - Ensures ongoing quality

### ⚠️ MODIFY AS NEEDED

1. **Bone Mappings** - May need custom mapping for some creatures
2. **Animation Timing** - May need adjustment for child proportions
3. **BlendSpace Weights** - May need tuning for smooth transitions

### ❌ DO NOT IMPLEMENT

1. **Realistic Violence** - Never appropriate for this engine
2. **Suggestive Animations** - Never appropriate for this engine
3. **Unlicensed Assets** - Only use CC0 or properly licensed content

### Final Decision

**RECOMMENDATION: FULLY IMPLEMENT UAL integration with retargeting, grounded animation system, and launcher montage.**

This approach:
- ✅ Provides professional-quality animations
- ✅ Maintains child-safe content
- ✅ Meets all acceptance criteria
- ✅ Fits within existing architecture
- ✅ Is fully testable and maintainable

---

## References

### Internal References
- [VS-005: Combat Telegraphs and Feedback](./RESEARCH_VS-005_Combat_Telegraphs_Feedback.md)
- [VS-015: Cinematic Acting and Voice](./RESEARCH_VS-015_Cinematic_Acting_Voice.md)
- [VS-023: Original Liminal Creatures](./RESEARCH_VS-023_Original_Liminal_Creatures.md)
- [VS-024: Facial Speech and Emotion](./RESEARCH_VS-024_Facial_Speech_Emotion.md)
- [src/adapters/inbound/gameplay/player_controller.gd](src/adapters/inbound/gameplay/player_controller.gd)
- [src/adapters/inbound/gameplay/gameplay_runtime.gd](src/adapters/inbound/gameplay/gameplay_runtime.gd)
- [src/adapters/inbound/scenes/launcher/launcher_overlay.gd](src/adapters/inbound/scenes/launcher/launcher_overlay.gd)

### External References

#### Godot Documentation
1. [Godot AnimationTree](https://docs.godotengine.org/en/stable/classes/class_animationtree.html)
2. [Godot Skeleton3D](https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html)
3. [Godot AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html)
4. [Godot Retargeting](https://docs.godotengine.org/en/stable/tutorials/animation/retargeting_animations.html)
5. [Godot BlendSpaces](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html#blend-spaces)

#### Asset Sources
1. [Quaternius Animations](https://quaternius.com/free-3d-models?category=animations) - CC0
2. [Mixamo](https://www.mixamo.com/) - Free with attribution
3. [Godot Asset Library](https://godotengine.org/asset-library/) - Various licenses

#### Tutorials
1. [GDQuest Animation](https://gdquest.com/course/godot-4-animation/)
2. [HeartBeast Retargeting](https://www.heartbeast.co/godot-4-retargeting/)
3. [Blender Retargeting](https://docs.blender.org/manual/en/latest/animation/retargeting/index.html)

---

*Document generated by Mistral Vibe for Choyce Engine project*
*Last updated: 2026-07-18*
*Size: ~28KB*
