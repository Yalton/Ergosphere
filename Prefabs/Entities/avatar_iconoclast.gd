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

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visible_on_screen_notifier: VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D
@onready var animation_tree: AnimationTree = $AnimationTree

enum State {
	IDLE,
	CHECKING_VISIBILITY,
	STARE,
	CHASE,
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
	
	# Start spawn sequence
	_start_spawn_sequence()

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	match current_state:
		State.IDLE:
			_process_idle_state(delta)
		State.CHECKING_VISIBILITY:
			_process_visibility_check_state(delta)
		State.STARE:
			_process_stare_state(delta)
		State.CHASE:
			_process_chase_state(delta)
		State.DESPAWNING:
			_process_despawn_state(delta)

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
		# Check if we're still visible after the delay
		if is_currently_visible:
			# Player has truly seen us
			has_been_seen = true
			DebugLogger.log_message("IconoclastAvatar", "Monster truly seen by player")
			
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
			# Player looked away, go back to idle
			DebugLogger.log_message("IconoclastAvatar", "Player looked away, returning to idle")
			current_state = State.IDLE

func _process_stare_state(delta):
	var player = CommonUtils.get_player()
	if not player:
		return
	
	# Turn to face player
	_rotate_towards_player(delta, player)
	
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
	
	# Update navigation target
	navigation_agent.target_position = player.global_position
	
	# Move towards target
	if navigation_agent.is_navigation_finished():
		return
	
	var next_position = navigation_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	
	# Apply movement
	velocity = direction * move_speed
	move_and_slide()
	
	# Keep facing player while chasing
	_rotate_towards_player(delta, player)
	
	# Count down chase timer
	chase_timer -= delta
	
	if chase_timer <= 0:
		DebugLogger.log_message("IconoclastAvatar", "Chase timer expired, despawning")
		_start_despawn_sequence()

func _process_despawn_state(delta):
	# Wait for collapse animation to finish before queue_free
	pass

func _start_spawn_sequence():
	DebugLogger.log_message("IconoclastAvatar", "Starting spawn sequence")
	
	# Hide armature initially
	if armature:
		armature.visible = false
	
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
		DebugLogger.log_warning("IconoclastAvatar", "No collapse sphere configured, showing armature immediately")
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
		DebugLogger.log_warning("IconoclastAvatar", "No collapse sphere configured, despawning immediately")
		queue_free()

func _on_collapse_finished():
	DebugLogger.log_message("IconoclastAvatar", "Collapse animation finished, destroying entity")
	queue_free()

func _rotate_towards_player(delta, player):
	if not player:
		return
	
	# Invert direction - face away becomes face towards
	var target_direction = -(player.global_position - global_position).normalized()
	target_direction.y = 0  # Keep rotation on horizontal plane
	
	if target_direction.length() > 0:
		var target_transform = transform.looking_at(global_position + target_direction, Vector3.UP)
		transform.basis = transform.basis.slerp(target_transform.basis, turn_speed * delta)

func _on_screen_entered():
	is_currently_visible = true
	
	# Don't react to visibility until spawn is complete
	if not has_spawned:
		return
	
	if not has_been_seen and current_state == State.IDLE:
		DebugLogger.log_message("IconoclastAvatar", "Monster potentially seen, checking visibility")
		current_state = State.CHECKING_VISIBILITY
		visibility_check_timer = visibility_confirmation_time

func _on_screen_exited():
	is_currently_visible = false
