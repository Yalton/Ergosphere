# Bed.gd
extends AwareGameObject

signal object_state_updated(interaction_text: String)
signal player_went_to_sleep


@export_group("Sleep Settings")
@export var sleep_animation_player: AnimationPlayer
@export var sleep_animation: String = "sleep"
@export var sleep_sound: AudioStream


func _ready() -> void:
	super._ready()
	module_name = "Bed"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Set display name
	if display_name.is_empty():
		display_name = "Bed"
	
	# Find task aware component
	task_aware_component = get_node_or_null("TaskAwareComponent")
	
	# Add to bed group for task system
	add_to_group("bed")
	
	DebugLogger.debug(module_name, "Bed initialized")

func interact(player_interaction: PlayerInteractionComponent) -> void:
	# Check if we can sleep (all other tasks done)
	if task_aware_component and not task_aware_component.is_task_available:
		player_interaction.send_message("You must complete all tasks before sleeping")
		return
	
	DebugLogger.info(module_name, "Player going to sleep")
	
	# Play sleep sound
	if sleep_sound:
		Audio.play_sound_3d(sleep_sound).global_position = global_position
	
	# Play animation if available
	if sleep_animation_player and sleep_animation_player.has_animation(sleep_animation):
		sleep_animation_player.play(sleep_animation)
		
		# Wait for animation
		if not sleep_animation_player.is_connected("animation_finished", _on_sleep_animation_finished):
			sleep_animation_player.animation_finished.connect(_on_sleep_animation_finished)
	else:
		# No animation, complete immediately
		_complete_sleep()

func _on_sleep_animation_finished(anim_name: String) -> void:
	if anim_name == sleep_animation:
		_complete_sleep()

func _complete_sleep() -> void:
	# Complete the sleep task
	if task_aware_component:
		task_aware_component.complete_task()
	
	# Emit signal
	player_went_to_sleep.emit()
	
	DebugLogger.info(module_name, "Sleep completed - day ended")
