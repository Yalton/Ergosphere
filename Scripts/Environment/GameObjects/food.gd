extends GameObject
class_name Food

signal consumed
signal object_state_updated(interaction_text: String)

@export_group("Food Settings")
@export var food_name: String = "Food"
@export var consume_sound: AudioStream
@export var consume_message: String = "You eat the food"
@export var nutrition_value: float = 50.0  # For future hunger system

@export var enable_debug: bool = true
var module_name: String = "Food"

func _ready() -> void:
	super._ready()
	DebugLogger.register_module(module_name, enable_debug)
	
	# Set display name
	if display_name.is_empty():
		display_name = food_name
	
	# Set interaction text
	object_state_updated.emit("Eat " + food_name)
	
	DebugLogger.debug(module_name, "Food initialized: " + food_name)

func interact(player_interaction: PlayerInteractionComponent) -> void:
	DebugLogger.info(module_name, "Player consuming food: " + food_name)
	
	# Play consume sound at this position
	if consume_sound:
		Audio.play_sound_3d(consume_sound).global_position = global_position
	
	# Send message to player
	player_interaction.send_message(consume_message)
	
	# Emit consumed signal (for hunger system later)
	consumed.emit()
	
	# Remove the food
	queue_free()
	
	DebugLogger.debug(module_name, "Food consumed and removed")
