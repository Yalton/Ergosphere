extends GameObject
class_name Bed

signal sleep_started
signal sleep_ended
signal object_state_updated(interaction_text: String)

@export var camera_sleep_position: Node3D  # Where the camera should move to
@export var sleep_duration: float = 3.0  # How long the sleep lasts
@export var enable_debug: bool = true

var module_name: String = "Bed"
var is_occupied: bool = false
var sleeping_player: Player = null

func _ready() -> void:
	super._ready()
	DebugLogger.register_module(module_name, enable_debug)
	
	# Set display name
	if display_name.is_empty():
		display_name = "Bed"
	
	# Ensure we have a camera position marker
	if not camera_sleep_position:
		# Create a default one if not assigned
		camera_sleep_position = Node3D.new()
		camera_sleep_position.name = "CameraSleepPosition"
		add_child(camera_sleep_position)
		# Position it above the bed pillow area
		camera_sleep_position.position = Vector3(0, 0.5, -0.5)
		camera_sleep_position.rotation_degrees = Vector3(75, 0, 0)  # Looking down at an angle
		DebugLogger.warning(module_name, "No camera sleep position assigned, created default")
	
	# Set initial interaction text
	_update_interaction_text()
	
	DebugLogger.debug(module_name, "Bed initialized")

func interact(player_interaction: PlayerInteractionComponent) -> void:
	if is_occupied:
		DebugLogger.debug(module_name, "Bed is already occupied")
		player_interaction.send_message("The bed is already in use")
		return
	
	var player = player_interaction.get_parent() as Player
	if not player:
		DebugLogger.error(module_name, "Could not get player from interaction component")
		return
	
	DebugLogger.info(module_name, "Player getting into bed")
	
	# Start sleep sequence
	is_occupied = true
	sleeping_player = player
	
	# Update interaction text while sleeping
	_update_interaction_text()
	
	# Get camera target transform
	var target_position = camera_sleep_position.global_position
	var target_rotation = camera_sleep_position.global_rotation
	
	# Tell player to move camera to sleep position
	player.move_camera_to_position(target_position, target_rotation)
	
	# Start sleep timer
	var sleep_timer = get_tree().create_timer(sleep_duration)
	sleep_timer.timeout.connect(_on_sleep_complete)
	
	# Emit signal for game manager
	sleep_started.emit()

func _on_sleep_complete() -> void:
	DebugLogger.info(module_name, "Sleep complete, waking up")
	
	if sleeping_player:
		# Tell player to restore camera
		sleeping_player.restore_camera_position()
	
	# Reset state
	is_occupied = false
	sleeping_player = null
	
	# Update interaction text back to normal
	_update_interaction_text()
	
	# Emit signal for game manager
	sleep_ended.emit()

func _update_interaction_text() -> void:
	var text = "Bed is occupied" if is_occupied else "Sleep"
	object_state_updated.emit(text)
