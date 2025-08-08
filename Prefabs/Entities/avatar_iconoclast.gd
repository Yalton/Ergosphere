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

func _physics_process(delta):
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
	pass

func _process_visibility_check_state(delta):
	visibility_check_timer -= delta
	
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
			current_state = State.DESPAWNING

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
		current_state = State.DESPAWNING

func _process_despawn_state(delta):
	queue_free()

func _rotate_towards_player(delta, player):
	if not player:
		return
	
	var target_direction = (player.global_position - global_position).normalized()
	target_direction.y = 0  # Keep rotation on horizontal plane
	
	if target_direction.length() > 0:
		var target_transform = transform.looking_at(global_position + target_direction, Vector3.UP)
		transform.basis = transform.basis.slerp(target_transform.basis, turn_speed * delta)

func _on_screen_entered():
	is_currently_visible = true
	
	if not has_been_seen and current_state == State.IDLE:
		DebugLogger.log_message("IconoclastAvatar", "Monster potentially seen, checking visibility")
		current_state = State.CHECKING_VISIBILITY
		visibility_check_timer = visibility_confirmation_time

func _on_screen_exited():
	is_currently_visible = false
