# SnakeDiegeticUI.gd
extends DiegeticUIBase

signal snake_game_completed(final_length: int)

@export var snake_game_control: SnakeGame  # Assign the SnakeGame node

## Enable debug logging

func _ready() -> void:
	super._ready()
	module_name = "SnakeDiegeticUI"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Set interaction text
	usable_interaction_text = "Play Snake Game"
	interaction_text = usable_interaction_text
	
	# Connect to snake game signals
	if snake_game_control:
		if snake_game_control.has_signal("game_completed"):
			snake_game_control.game_completed.connect(_on_snake_game_completed)
			DebugLogger.debug(module_name, "Connected to snake game signals")
		else:
			DebugLogger.error(module_name, "Snake game control doesn't have game_completed signal!")
	else:
		DebugLogger.error(module_name, "No snake game control assigned!")
	
	DebugLogger.debug(module_name, "Snake Diegetic UI initialized")

func start_interaction() -> void:
	super.start_interaction()
	
	# Additional setup for snake game if needed
	DebugLogger.debug(module_name, "Snake game interaction started")

func end_interaction() -> void:
	# Stop the game when interaction ends
	if snake_game_control:
		snake_game_control.stop_game()
	
	super.end_interaction()
	DebugLogger.debug(module_name, "Snake game interaction ended")

func _on_snake_game_completed(final_length: int) -> void:
	DebugLogger.info(module_name, "Snake game completed with length: " + str(final_length))
	
	# Relay the signal to external listeners
	snake_game_completed.emit(final_length)
	
	# End interaction after completion
	await get_tree().create_timer(1.0).timeout
	end_interaction()

func _on_day_reset_custom() -> void:
	# Reset snake game on day reset if needed
	if snake_game_control:
		snake_game_control.stop_game()
		DebugLogger.debug(module_name, "Snake game reset for new day")
