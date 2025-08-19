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
## Speed reduction factor when flashlight is on monster
@export var flashlight_speed_factor: float = 0.5
## Node containing RayCast3D children for visibility checking
@export var raycasts_node: Node3D
## Minimum number of raycasts that must hit player to confirm visibility
@export var min_raycast_hits: int = 2

@export_group("Kill Mechanic")
## Distance at which the monster can catch the player
@export var catch_distance: float = 2.0
## Duration of the camera forced look at monster
@export var forced_look_duration: float = 2.0
## Target FOV when zooming in on monster
@export var zoom_fov: float = 30.0
## Path to main menu scene
@export_file("*.tscn") var main_menu_path: String = "res://scenes/ui/main_menu.tscn"

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
var is_currently_visible: bool = false
var despawn_tween: Tween
var spawn_tween: Tween
var has_spawned: bool = false
var is_flashlight_on_monster: bool = false
var raycasts: Array[RayCast3D] = []
var has_caught_player: bool = false
var player_ref: Node3D = null
var original_camera_fov: float = 75.0

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
	
	# Always face the player when spawned (unless catching)
	if has_spawned and current_state != State.CATCHING_PLAYER:
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
	# Just waiting to be seen
	move_and_slide()  # Still process physics for gravity
	
	# Don't process visibility until spawn is complete
	if not has_spawned:
		return

func _process_visibility_check_state(delta):
	visibility_check_timer -= delta
	move_and_slide()  # Process physics for gravity
	
	if visibility_check_timer <= 0:
		DebugLogger.log_message("IconoclastAvatar", "Visibility timer expired, checking conditions...")
		DebugLogger.log_message("IconoclastAvatar", "Is currently visible (frustum): %s" % is_currently_visible)
		
		# Check if we're still visible after the delay AND not occluded
		var line_of_sight = _check_player_line_of_sight()
		
		if is_currently_visible and line_of_sight:
			# Player has truly seen us
			has_been_seen = true
			DebugLogger.log_message("IconoclastAvatar", "PLAYER HAS SEEN THE MONSTER!")
			
			# Trigger glitch effect on player
			_trigger_player_glitch_effect()
			
			# Flip coin to decide behavior
			will_chase = randf() > 0.5
			
			# Start staring
			current_state = State.STARE
			stare_timer = stare_duration
			
			if will_chase:
				DebugLogger.log_message("IconoclastAvatar", "Will chase after stare")
			else:
				DebugLogger.log_message("IconoclastAvatar", "Will despawn after stare")
		else:
			# Player looked away or geometry blocking view, go back to idle
			DebugLogger.log_message("IconoclastAvatar", "Visibility check failed - returning to idle (visible: %s, LOS: %s)" % [is_currently_visible, line_of_sight])
			current_state = State.IDLE

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
	if player.has_method("is_interacting_with_ui"):
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
	if TransitionManager:
		# This method handles fade to black, scene change, and fade from black
		TransitionManager.transition_to_scene(main_menu_path)
	else:
		# Direct scene change
		get_tree().change_scene_to_file(main_menu_path)

func _check_player_line_of_sight() -> bool:
	var player = CommonUtils.get_player()
	if not player:
		DebugLogger.warning("IconoclastAvatar", "No player found for line of sight check")
		return false
	
	if raycasts.is_empty():
		DebugLogger.warning("IconoclastAvatar", "No raycasts available for visibility check")
		return false
	
	var hit_count = 0
	DebugLogger.log_message("IconoclastAvatar", "Checking %d raycasts for player visibility" % raycasts.size())
	
	# Check each raycast
	for i in range(raycasts.size()):
		var raycast = raycasts[i]
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider == player:
				hit_count += 1
				DebugLogger.log_message("IconoclastAvatar", "Raycast %d (%s) HIT player" % [i, raycast.name])
			else:
				DebugLogger.log_message("IconoclastAvatar", "Raycast %d (%s) hit %s instead of player" % [i, raycast.name, collider.name if collider else "null"])
		else:
			DebugLogger.log_message("IconoclastAvatar", "Raycast %d (%s) not colliding with anything" % [i, raycast.name])
	
	# Check if enough raycasts hit the player
	var result = hit_count >= min_raycast_hits
	DebugLogger.log_message("IconoclastAvatar", "Visibility result: %s (hits: %d/%d, required: %d)" % [result, hit_count, raycasts.size(), min_raycast_hits])
	return result

func _check_flashlight_status():
	var player = CommonUtils.get_player()
	if not player:
		is_flashlight_on_monster = false
		return
	
	# Check if flashlight is on and pointing at monster
	if is_currently_visible and player.flashlight_on:
		# Simple check - if we're visible and flashlight is on, assume it's on us
		# Later you could add more sophisticated directional checking
		is_flashlight_on_monster = true
	else:
		is_flashlight_on_monster = false

func _trigger_player_glitch_effect():
	var player = CommonUtils.get_player()
	if not player:
		return
	
	# Play glitch effect for 1-2 seconds
	var glitch_duration = randf_range(1.0, 2.0)
	player.trigger_player_vfx("glitch", 0.1, glitch_duration, 0.1)
	DebugLogger.log_message("IconoclastAvatar", "Triggered glitch effect for %.2f seconds" % glitch_duration)

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
	
	has_spawned = true

func _start_despawn_sequence():
	current_state = State.DESPAWNING
	DebugLogger.log_message("IconoclastAvatar", "Starting despawn sequence")
	
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
	
	if not has_been_seen and current_state == State.IDLE:
		DebugLogger.log_message("IconoclastAvatar", "Starting visibility check - timer set to %.1f seconds" % visibility_confirmation_time)
		current_state = State.CHECKING_VISIBILITY
		visibility_check_timer = visibility_confirmation_time

func _on_screen_exited():
	is_currently_visible = false
	is_flashlight_on_monster = false  # Can't be lit if not visible
	DebugLogger.log_message("IconoclastAvatar", "Monster exited screen (no longer in camera frustum)")
