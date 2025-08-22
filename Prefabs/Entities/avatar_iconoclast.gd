extends CharacterBody3D
class_name IconoclastAvatar

## Speed at which the monster moves when chasing
@export var move_speed: float = 3.0
## How long the monster stares at player before deciding action (seconds)
@export var stare_duration: float = 2.0
## Minimum chase duration before despawning (seconds)
@export var min_chase_duration: float = 10.0
## Maximum chase duration before despawning (seconds)
@export var max_chase_duration: float = 30.0
## Turn speed when rotating to face player (radians per second)
@export var turn_speed: float = 3.0
## Time monster must remain visible before considered "truly seen" (seconds)
@export var visibility_confirmation_time: float = 1.0
## Gravity strength
@export var gravity: float = 9.8
## Armature node to hide when despawning
@export var armature: Node3D
## Sphere mesh with collapse shader
@export var collapse_sphere: MeshInstance3D
## Duration of the collapse animation (seconds)
@export var collapse_duration: float = 1.0
## Particle effect that emits while entity is active
@export var particle_effect: GPUParticles3D
## Speed reduction factor when flashlight is on monster
@export var flashlight_speed_factor: float = 0.5
## Node containing RayCast3D children for visibility checking
@export var raycasts_node: Node3D
## Minimum number of raycasts that must hit player to confirm visibility
@export var min_raycast_hits: int = 2
## How often to recheck visibility when visible but no LOS (seconds)
@export var visibility_recheck_interval: float = 1.0
## Distance at which monster automatically detects player
@export var auto_detect_distance: float = 8.0

@export_group("Kill Mechanic")
## Distance at which the monster can catch the player
@export var catch_distance: float = 2.0
## Duration of the camera forced look at monster
@export var forced_look_duration: float = 2.0
## Target FOV when zooming in on monster
@export var zoom_fov: float = 30.0
## Path to main menu scene
@export_file("*.tscn") var main_menu_path: String = "res://scenes/ui/main_menu.tscn"

@export_group("Testing")
## Force monster to always chase when seen (for testing)
@export var always_chase: bool = false

@export_group("Audio")
## Audio player for when entity appears
@export var appear_audio_player: AudioStreamPlayer3D
## Audio player for when entity vanishes
@export var vanish_audio_player: AudioStreamPlayer3D
## Audio player for when entity captures the player
@export var capture_audio_player: AudioStreamPlayer3D

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visible_on_screen_notifier: VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D
@onready var animation_tree: AnimationTree = $AnimationTree

enum State {
	IDLE,
	ROAMING,
	CHECKING_VISIBILITY,
	STARE,
	CHASE,
	CATCHING_PLAYER,
	DESPAWNING
}

var current_state: State = State.IDLE
var has_been_seen: bool = false
var stare_timer: float = 0.0
var chase_timer: float = 0.0
var chase_duration: float = 0.0
var will_chase: bool = false
var visibility_check_timer: float = 0.0
var visibility_recheck_timer: float = 0.0
var is_currently_visible: bool = false
var despawn_tween: Tween
var spawn_tween: Tween
var has_spawned: bool = false
var is_flashlight_on_monster: bool = false
var raycasts: Array[RayCast3D] = []
var has_caught_player: bool = false
var player_ref: Node3D = null
var original_camera_fov: float = 75.0

# Roaming state variables
var idle_timer: float = 0.0
var idle_duration: float = 0.0
var roam_timer: float = 0.0
var roam_target: Vector3 = Vector3.ZERO
var was_visible_during_roam: bool = false

func _ready():
	DebugLogger.register_module("IconoclastAvatar")
	
	# Set up navigation agent
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = 1.0
	
	# Connect visible notifier signals
	visible_on_screen_notifier.screen_entered.connect(_on_screen_entered)
	visible_on_screen_notifier.screen_exited.connect(_on_screen_exited)
	
	# Start in idle animation
	animation_tree.set_to_idle()
	
	# Collect all RayCast3D nodes from the raycasts container
	if raycasts_node:
		for child in raycasts_node.get_children():
			if child is RayCast3D:
				raycasts.append(child)
				DebugLogger.log_message("IconoclastAvatar", "Found raycast: " + child.name)
		DebugLogger.log_message("IconoclastAvatar", "Total raycasts configured: " + str(raycasts.size()))
	else:
		DebugLogger.warning("IconoclastAvatar", "No raycasts node configured - visibility checking will not work!")
	
	# Start spawn sequence
	_start_spawn_sequence()

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle facing direction based on state
	if has_spawned and current_state != State.CATCHING_PLAYER:
		if current_state == State.ROAMING:
			# Face movement direction when roaming
			if velocity.length() > 0.1:
				_rotate_towards_direction(delta, velocity.normalized())
		else:
			# Face player in all other states
			var player = CommonUtils.get_player()
			if player:
				_rotate_towards_player(delta, player)
	
	# Check flashlight status
	_check_flashlight_status()
	
	# Log state changes for debugging
	var old_state = current_state
	
	match current_state:
		State.IDLE:
			_process_idle_state(delta)
		State.ROAMING:
			_process_roaming_state(delta)
		State.CHECKING_VISIBILITY:
			_process_visibility_check_state(delta)
		State.STARE:
			_process_stare_state(delta)
		State.CHASE:
			_process_chase_state(delta)
		State.CATCHING_PLAYER:
			_process_catching_state(delta)
		State.DESPAWNING:
			_process_despawn_state(delta)
	
	# Log state transitions
	if old_state != current_state:
		DebugLogger.log_message("IconoclastAvatar", "State changed from %s to %s" % [State.keys()[old_state], State.keys()[current_state]])

func _process_idle_state(delta):
	# Just waiting to be seen or start roaming
	move_and_slide()  # Still process physics for gravity
	
	# Don't process visibility until spawn is complete
	if not has_spawned:
		return
	
	# Check for proximity detection even in idle
	var player = CommonUtils.get_player()
	if player:
		var distance = global_position.distance_to(player.global_position)
		if distance <= auto_detect_distance and not has_been_seen:
			DebugLogger.log_message("IconoclastAvatar", "Player within auto-detect range (%.1f), triggering detection" % distance)
			_trigger_detection(true)  # Always chase when proximity detected
			return
	
	# Increment idle timer for roaming behavior
	idle_timer += delta
	
	# Check if we should start roaming
	if idle_timer >= idle_duration:
		_start_roaming()

func _process_visibility_check_state(delta):
	move_and_slide()  # Process physics for gravity
	
	# Decrement the recheck timer
	visibility_recheck_timer -= delta
	
	# Check visibility at intervals
	if visibility_recheck_timer <= 0:
		visibility_recheck_timer = visibility_recheck_interval
		
		# Check proximity first
		var player = CommonUtils.get_player()
		if player:
			var distance = global_position.distance_to(player.global_position)
			if distance <= auto_detect_distance:
				DebugLogger.log_message("IconoclastAvatar", "Player within auto-detect range (%.1f), triggering detection" % distance)
				_trigger_detection(true)  # Always chase when proximity detected
				return
		
		# Check line of sight if we're visible
		if is_currently_visible:
			var line_of_sight = _check_player_line_of_sight()
			
			if line_of_sight:
				# Player has truly seen us
				DebugLogger.log_message("IconoclastAvatar", "PLAYER HAS LINE OF SIGHT TO MONSTER!")
				_trigger_detection(false)  # Use normal chase logic
			else:
				DebugLogger.log_message("IconoclastAvatar", "Still checking visibility - no line of sight yet")

func _trigger_detection(force_chase: bool):
	has_been_seen = true
	
	# Determine behavior
	if always_chase or force_chase:
		will_chase = true
		DebugLogger.log_message("IconoclastAvatar", "Will chase (forced: %s, always: %s)" % [force_chase, always_chase])
	else:
		# Flip coin to decide behavior
		will_chase = randf() > 0.5
		DebugLogger.log_message("IconoclastAvatar", "Coin flip: will %s" % ("chase" if will_chase else "despawn"))
	
	# Only trigger effects if we're going to chase
	if will_chase:
		_trigger_player_effects()
	
	# Start staring
	current_state = State.STARE
	stare_timer = stare_duration

func _trigger_player_effects():
	var player = CommonUtils.get_player()
	if not player:
		return
	
	DebugLogger.log_message("IconoclastAvatar", "Triggering player effects sequence")
	
	# Start with blink effect
	player.trigger_player_vfx("blink", 0.1, 0.3, 0.1)
	
	# Wait for blink to reach peak darkness, then start glitch
	await get_tree().create_timer(0.15).timeout
	
	# Play glitch effect
	var glitch_duration = randf_range(1.0, 2.0)
	player.trigger_player_vfx("glitch", 0.1, glitch_duration, 0.1)
	
	# End with another blink after glitch
	await get_tree().create_timer(glitch_duration).timeout
	player.trigger_player_vfx("blink", 0.1, 0.3, 0.1)
	
	DebugLogger.log_message("IconoclastAvatar", "Player effects sequence complete")

func _process_stare_state(delta):
	# Process physics for gravity
	move_and_slide()
	
	# Count down stare timer
	stare_timer -= delta
	
	if stare_timer <= 0:
		if will_chase:
			DebugLogger.log_message("IconoclastAvatar", "Starting chase")
			current_state = State.CHASE
			chase_duration = randf_range(min_chase_duration, max_chase_duration)
			chase_timer = chase_duration
			# Switch to walk animation
			animation_tree.set_to_walk()
		else:
			DebugLogger.log_message("IconoclastAvatar", "Despawning after stare")
			_start_despawn_sequence()

func _process_chase_state(delta):
	var player = CommonUtils.get_player()
	if not player:
		return
	
	# Check if we're close enough to catch the player
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= catch_distance and not has_caught_player:
		DebugLogger.log_message("IconoclastAvatar", "Within catch distance, initiating catch sequence")
		_catch_player(player)
		return
	
	# Update navigation target
	navigation_agent.target_position = player.global_position
	
	# Move towards target
	if navigation_agent.is_navigation_finished():
		return
	
	var next_position = navigation_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	
	# Apply movement with flashlight speed modifier
	var current_speed = move_speed
	if is_flashlight_on_monster:
		current_speed *= flashlight_speed_factor
	
	velocity = direction * current_speed
	move_and_slide()
	
	# Count down chase timer
	chase_timer -= delta
	
	if chase_timer <= 0:
		DebugLogger.log_message("IconoclastAvatar", "Chase timer expired, despawning")
		_start_despawn_sequence()

func _process_catching_state(delta):
	# Just wait for the catch sequence to complete
	move_and_slide()

func _process_despawn_state(delta):
	# Wait for collapse animation to finish before queue_free
	pass

func _catch_player(player: Node3D):
	if has_caught_player:
		return
	
	has_caught_player = true
	current_state = State.CATCHING_PLAYER
	player_ref = player
	
	DebugLogger.log_message("IconoclastAvatar", "Catching player!")
	
	# Stop player movement
	player.is_interacting_with_ui = true
	
	# Play reach out animation
	if animation_tree:
		animation_tree.set("parameters/reach_out/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		DebugLogger.log_message("IconoclastAvatar", "Triggered reach_out animation")
	
	# Force player to look at monster
	_force_player_look()
	
	# Play capture audio
	if capture_audio_player:
		capture_audio_player.play()
		DebugLogger.log_message("IconoclastAvatar", "Playing capture audio")
	
	# Wait for the forced look duration, then transition to main menu
	await get_tree().create_timer(forced_look_duration).timeout
	_transition_to_main_menu()

func _force_player_look():
	if not player_ref:
		return
	
	var camera = get_viewport().get_camera_3d()
	if not camera:
		DebugLogger.warning("IconoclastAvatar", "Could not find player camera")
		return
	
	# Store original FOV
	original_camera_fov = camera.fov
	
	# Calculate direction from player to monster
	var direction_to_monster = (global_position - player_ref.global_position).normalized()
	
	# Create target transform looking at monster
	var target_pos = global_position + Vector3(0, 1.5, 0)  # Look at chest/head area
	
	# Create tween for smooth camera movement
	var camera_tween = create_tween()
	camera_tween.set_parallel(true)
	
	# Tween the player rotation to face monster
	var target_y_rotation = atan2(-direction_to_monster.x, -direction_to_monster.z)
	camera_tween.tween_property(player_ref, "rotation:y", target_y_rotation, 0.5)
	
	# Calculate pitch to look at monster's chest/head
	var player_eye_pos = player_ref.global_position + Vector3(0, 1.6, 0)  # Approximate eye height
	var to_monster = target_pos - player_eye_pos
	var pitch = asin(to_monster.normalized().y)
	
	# Find the head node if it exists (assuming structure like Player/Head)
	var head = player_ref.get_node_or_null("Head")
	if head:
		camera_tween.tween_property(head, "rotation:x", -pitch, 0.5)
	
	# Zoom in camera
	camera_tween.tween_property(camera, "fov", zoom_fov, 0.5)
	
	DebugLogger.log_message("IconoclastAvatar", "Forcing player to look at monster with FOV: %f" % zoom_fov)

func _transition_to_main_menu():
	DebugLogger.log_message("IconoclastAvatar", "Transitioning to main menu after catch")
	
	# Use TransitionManager if available
	TransitionManager.transition_to_scene(main_menu_path)

func _check_player_line_of_sight() -> bool:
	var player = CommonUtils.get_player()
	if not player:
		DebugLogger.warning("IconoclastAvatar", "No player found for line of sight check")
		return false
	
	if raycasts.is_empty():
		DebugLogger.warning("IconoclastAvatar", "No raycasts available for visibility check")
		return false
	
	var hit_count = 0
	
	# Check each raycast
	for i in range(raycasts.size()):
		var raycast = raycasts[i]
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider == player:
				hit_count += 1
				DebugLogger.log_message("IconoclastAvatar", "Raycast %d (%s) HIT player" % [i, raycast.name])
	
	# Check if enough raycasts hit the player
	var result = hit_count >= min_raycast_hits
	DebugLogger.log_message("IconoclastAvatar", "Visibility result: %s (hits: %d/%d, required: %d)" % [result, hit_count, raycasts.size(), min_raycast_hits])
	return result

func _check_flashlight_status():
	var player = CommonUtils.get_player()
	if not player:
		is_flashlight_on_monster = false
		return
	
	var was_flashlight_on = is_flashlight_on_monster
	
	# Check if flashlight is on through the component
	var flashlight_component = player.flashlight_component
	if not flashlight_component:
		DebugLogger.warning("IconoclastAvatar", "Player has no flashlight component")
		is_flashlight_on_monster = false
		return
	
	# Check if flashlight is on and pointing at monster
	if is_currently_visible and flashlight_component.flashlight_on:
		# Simple check - if we're visible and flashlight is on, assume it's on us
		# Later you could add more sophisticated directional checking
		is_flashlight_on_monster = true
	else:
		is_flashlight_on_monster = false
	
	# Update animation speed if flashlight status changed
	if was_flashlight_on != is_flashlight_on_monster and animation_tree:
		if is_flashlight_on_monster:
			# Slow down animations when flashlight is on monster
			animation_tree.set_speed_scale(flashlight_speed_factor)
			DebugLogger.log_message("IconoclastAvatar", "Flashlight on monster - slowing animations")
		else:
			# Reset animation speed when flashlight is off
			animation_tree.reset_speed_scale()
			DebugLogger.log_message("IconoclastAvatar", "Flashlight off monster - normal animation speed")

func _start_spawn_sequence():
	DebugLogger.log_message("IconoclastAvatar", "Starting spawn sequence")
	
	# Hide armature initially
	if armature:
		armature.visible = false
	
	# Play appear audio
	if appear_audio_player:
		appear_audio_player.play()
		DebugLogger.log_message("IconoclastAvatar", "Playing appear audio")
	
	# Set up and show collapse sphere at full collapse
	if collapse_sphere and collapse_sphere.material_override:
		collapse_sphere.visible = true
		collapse_sphere.material_override.set_shader_parameter("collapse_progress", 1.0)
		
		# Create tween for expand animation
		if spawn_tween and spawn_tween.is_valid():
			spawn_tween.kill()
		
		spawn_tween = create_tween()
		
		# Animate collapse_progress from 1 to 0 (expanding)
		spawn_tween.tween_property(
			collapse_sphere.material_override,
			"shader_parameter/collapse_progress",
			0.0,
			collapse_duration
		).from(1.0)
		
		# When expansion completes, switch to armature
		spawn_tween.finished.connect(_on_spawn_finished)
	else:
		# No collapse sphere, just show armature immediately
		DebugLogger.warning("IconoclastAvatar", "No collapse sphere configured, showing armature immediately")
		if armature:
			armature.visible = true
		has_spawned = true

func _on_spawn_finished():
	DebugLogger.log_message("IconoclastAvatar", "Spawn animation finished, showing entity")
	
	# Hide sphere
	if collapse_sphere:
		collapse_sphere.visible = false
	
	# Show armature
	if armature:
		armature.visible = true
	
	# Start particle effect
	if particle_effect:
		particle_effect.emitting = true
		DebugLogger.log_message("IconoclastAvatar", "Started particle effect")
	
	has_spawned = true
	
	# Set initial idle duration
	idle_duration = randf_range(5.0, 15.0)
	idle_timer = 0.0
	DebugLogger.log_message("IconoclastAvatar", "Initial idle duration set to %.1f seconds" % idle_duration)

func _start_despawn_sequence():
	current_state = State.DESPAWNING
	DebugLogger.log_message("IconoclastAvatar", "Starting despawn sequence")
	
	# Stop particle effect
	if particle_effect:
		particle_effect.emitting = false
		DebugLogger.log_message("IconoclastAvatar", "Stopped particle effect")
	
	# Play vanish audio
	if vanish_audio_player:
		vanish_audio_player.play()
		DebugLogger.log_message("IconoclastAvatar", "Playing vanish audio")
	
	# Hide the armature
	if armature:
		armature.visible = false
	
	# Show and animate the collapse sphere
	if collapse_sphere and collapse_sphere.material_override:
		collapse_sphere.visible = true
		
		# Create tween for collapse animation
		if despawn_tween and despawn_tween.is_valid():
			despawn_tween.kill()
		
		despawn_tween = create_tween()
		
		# Animate collapse_progress from 0 to 1
		despawn_tween.tween_property(
			collapse_sphere.material_override, 
			"shader_parameter/collapse_progress", 
			1.0, 
			collapse_duration
		).from(0.0)
		
		# Queue free when animation completes
		despawn_tween.finished.connect(_on_collapse_finished)
	else:
		# No collapse sphere, just queue free immediately
		DebugLogger.warning("IconoclastAvatar", "No collapse sphere configured, despawning immediately")
		queue_free()

func _on_collapse_finished():
	DebugLogger.log_message("IconoclastAvatar", "Collapse animation finished, destroying entity")
	queue_free()

func _start_roaming():
	DebugLogger.log_message("IconoclastAvatar", "Starting roaming behavior")
	
	# Reset timers
	idle_timer = 0.0
	roam_timer = 0.0
	was_visible_during_roam = false
	
	# Determine if we should move near player (10% chance)
	var move_near_player = randf() < 0.1
	
	var player = CommonUtils.get_player()
	if move_near_player and player:
		# Pick a random position within 10 units of player
		var angle = randf() * TAU
		var distance = randf_range(5.0, 10.0)
		var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		roam_target = player.global_position + offset
		DebugLogger.log_message("IconoclastAvatar", "Roaming towards player area (distance: %.1f)" % distance)
	else:
		# Pick a random position within 20 units of current position
		var angle = randf() * TAU
		var distance = randf_range(5.0, 20.0)
		var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		roam_target = global_position + offset
		DebugLogger.log_message("IconoclastAvatar", "Roaming to random location (distance: %.1f)" % distance)
	
	# Set the navigation target
	navigation_agent.target_position = roam_target
	
	# Switch to roaming state
	current_state = State.ROAMING
	
	# Start walk animation
	if animation_tree:
		animation_tree.set_to_walk()

func _process_roaming_state(delta):
	# Check if player can see us - if so, immediately return to idle
	if is_currently_visible:
		if not was_visible_during_roam:
			DebugLogger.log_message("IconoclastAvatar", "Player spotted entity during roam - freezing")
			was_visible_during_roam = true
		
		# Stop moving and go back to idle animation
		velocity = Vector3.ZERO
		if animation_tree:
			animation_tree.set_to_idle()
		move_and_slide()
		return
	else:
		# If we were visible but now aren't, resume roaming
		if was_visible_during_roam:
			DebugLogger.log_message("IconoclastAvatar", "Player looked away - resuming roam")
			was_visible_during_roam = false
			if animation_tree:
				animation_tree.set_to_walk()
	
	# Check for proximity detection while roaming
	var player = CommonUtils.get_player()
	if player:
		var distance = global_position.distance_to(player.global_position)
		if distance <= auto_detect_distance and not has_been_seen:
			DebugLogger.log_message("IconoclastAvatar", "Player within auto-detect range during roam (%.1f), triggering detection" % distance)
			_trigger_detection(true)
			return
	
	# Increment roam timer
	roam_timer += delta
	
	# Check if we've been roaming too long (20 seconds contingency)
	if roam_timer >= 20.0:
		DebugLogger.log_message("IconoclastAvatar", "Roam timeout - returning to idle")
		_return_to_idle()
		return
	
	# Check if we've reached our destination
	if navigation_agent.is_navigation_finished():
		DebugLogger.log_message("IconoclastAvatar", "Reached roam destination - returning to idle")
		_return_to_idle()
		return
	
	# Continue moving towards target
	var next_position = navigation_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	
	# Move at regular speed (not affected by flashlight during roam)
	velocity = direction * move_speed
	move_and_slide()

func _return_to_idle():
	DebugLogger.log_message("IconoclastAvatar", "Returning to idle state")
	
	# Stop movement
	velocity = Vector3.ZERO
	
	# Switch to idle animation
	if animation_tree:
		animation_tree.set_to_idle()
	
	# Reset to idle state
	current_state = State.IDLE
	
	# Set new idle duration
	idle_duration = randf_range(5.0, 15.0)
	idle_timer = 0.0
	
	DebugLogger.log_message("IconoclastAvatar", "Next idle duration: %.1f seconds" % idle_duration)

func _rotate_towards_direction(delta, direction: Vector3):
	if direction.length() == 0:
		return
	
	# Keep rotation on horizontal plane
	direction.y = 0
	direction = direction.normalized()
	
	if direction.length() > 0:
		var target_transform = transform.looking_at(global_position + direction, Vector3.UP)
		transform.basis = transform.basis.slerp(target_transform.basis, turn_speed * delta)

func _rotate_towards_player(delta, player):
	if not player:
		return
	
	# Face away from the player (show back to player)
	var target_direction = -(player.global_position - global_position).normalized()
	target_direction.y = 0  # Keep rotation on horizontal plane
	
	if target_direction.length() > 0:
		var target_transform = transform.looking_at(global_position + target_direction, Vector3.UP)
		transform.basis = transform.basis.slerp(target_transform.basis, turn_speed * delta)

func _on_screen_entered():
	is_currently_visible = true
	DebugLogger.log_message("IconoclastAvatar", "Monster entered screen (visible to camera frustum)")
	
	# Don't react to visibility until spawn is complete
	if not has_spawned:
		DebugLogger.log_message("IconoclastAvatar", "Not reacting - spawn not complete")
		return
	
	# If we're roaming, we don't trigger detection - we just freeze
	if current_state == State.ROAMING:
		DebugLogger.log_message("IconoclastAvatar", "Visible during roam - freezing movement")
		return
	
	if not has_been_seen and current_state == State.IDLE:
		DebugLogger.log_message("IconoclastAvatar", "Starting visibility check")
		current_state = State.CHECKING_VISIBILITY
		visibility_recheck_timer = 0.0  # Check immediately

func _on_screen_exited():
	is_currently_visible = false
	is_flashlight_on_monster = false  # Can't be lit if not visible
	DebugLogger.log_message("IconoclastAvatar", "Monster exited screen (no longer in camera frustum)")
	
	# If we were checking visibility, go back to idle
	if current_state == State.CHECKING_VISIBILITY and not has_been_seen:
		DebugLogger.log_message("IconoclastAvatar", "Player looked away during visibility check - returning to idle")
		current_state = State.IDLE
		# Reset idle timer so we don't immediately start roaming
		idle_timer = 0.0
		idle_duration = randf_range(5.0, 15.0)
