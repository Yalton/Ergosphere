# bed.gd
extends AwareGameObject

signal sleep_initiated
#signal object_state_updated(interaction_text: String)

@export_group("Bed Settings")
## Camera position when player is looking at the bed
@export var camera_position: Node3D
## Camera rotation when player is looking at the bed  
@export var camera_rotation: Vector3 = Vector3.ZERO
## Duration of camera transition to bed
@export var camera_transition_duration: float = 1.5
## Sleep sound effect
@export var sleep_sound: AudioStream



func _ready() -> void:
	super._ready()
	module_name = "Bed"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Set display name if not already set
	if display_name.is_empty():
		display_name = "Bed"
	
	# Find task aware component
	task_aware_component = get_node_or_null("TaskAwareComponent")
	
	# Add to beds group for task system
	add_to_group("beds")
	
	# Set interaction text
	object_state_updated.emit("Sleep")
	
	DebugLogger.debug(module_name, "Bed initialized")

func interact(player_interaction: PlayerInteractionComponent) -> void:
	# Check if sleep task is available
	if task_aware_component: 
		task_aware_component.update_task_availability()
	if task_aware_component and not task_aware_component.is_task_available:
		DebugLogger.debug(module_name, "Sleep task not available")
		return
	
	DebugLogger.info(module_name, "Player initiating sleep")
	
	# Play sleep sound
	if sleep_sound:
		Audio.play_sound(sleep_sound)
	
	# Get player reference
	var player : Player = player_interaction.get_parent()
	if not player:
		DebugLogger.error(module_name, "Could not find player")
		return
	
	# Move camera to bed view
	if camera_position:
		player.move_camera_to_position(
			camera_position.global_position,
			camera_position.rotation,
			camera_transition_duration
		)
	else:
		DebugLogger.warning(module_name, "No camera position set for bed")
	
	# Wait for camera transition
	await get_tree().create_timer(camera_transition_duration).timeout
	
	# Start fade to black and reset
	_initiate_sleep_sequence(player)

func _initiate_sleep_sequence(player: Player) -> void:
	# Fade to black
	if TransitionManager:
		await TransitionManager.fade_to_black()
		
		# Reset the level during black screen
		_reset_day()
		
		# Small delay to ensure reset is complete
		await get_tree().create_timer(0.5).timeout
		
		# Restore camera
		player.restore_camera_position(1.0)
		
		# Fade back in
		await TransitionManager.fade_from_black()
	else:
		DebugLogger.error(module_name, "TransitionManager not found")
		# Fallback - just reset and restore camera
		_reset_day()
		player.restore_camera_position(1.0)
	
	# Complete the sleep task
	if task_aware_component:
		task_aware_component.complete_task()
	
	sleep_initiated.emit()
	DebugLogger.info(module_name, "Sleep sequence completed")

func _reset_day() -> void:
	DebugLogger.debug(module_name, "Resetting day")
	GameManager.start_new_day()
