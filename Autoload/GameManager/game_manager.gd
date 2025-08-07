extends Node

signal game_started
signal game_ended
signal day_started(day_number: int)
signal day_ended(day_number: int)
signal player_sleeping()
## Current day number in the game
@export var current_day: int = 0

## Maximum number of days before game ends
@export var max_days: int = 5

var event_manager: EventManager
var state_manager: StateManager
var task_manager: TaskManager
var storage_manager: StorageManager
var audio_fx_manager: AudioFXManager
var ending_sequence_manager: EndingSequenceManager

var session_password: String = ""
var game_is_running: bool = false
var systems_initialized: bool = false

# Settings for Hawking Radiation punishment
@export_group("Hawking Radiation Punishment")
## Duration of the radiation effects in seconds
@export var radiation_effect_duration: float = 5.0
## Movement speed multiplier when affected (0.3 = 30% speed)
@export var radiation_speed_multiplier: float = 0.3
## Sanity loss from radiation exposure
@export var radiation_sanity_loss: float = 20.0
## Particle effect to spawn on player
@export var radiation_particle_scene: PackedScene
## Audio to play during radiation exposure
@export var radiation_audio: AudioStream
## Audio to play when radiation ends
@export var radiation_end_audio: AudioStream


func _ready():
	DebugLogger.register_module("GameManager")
	
	# Find managers using CommonUtils
	event_manager = CommonUtils.safe_get_node(self, "EventManager") as EventManager
	state_manager = CommonUtils.safe_get_node(self, "StateManager") as StateManager
	task_manager = CommonUtils.safe_get_node(self, "TaskManager") as TaskManager
	storage_manager = CommonUtils.safe_get_node(self, "StorageManager") as StorageManager
	audio_fx_manager = CommonUtils.safe_get_node(self, "AudioFXManager") as AudioFXManager
	ending_sequence_manager = CommonUtils.safe_get_node(self, "EndingSequenceManager") as EndingSequenceManager
	
	DebugLogger.info("GameManager", "GameManager ready, waiting for game start")

func initialize_systems():
	"""Initialize all game systems but don't start the game"""
	if systems_initialized:
		return
		
	DebugLogger.info("GameManager", "Initializing all systems")
	
	# Initialize managers
	if state_manager and state_manager.has_method("initialize"):
		state_manager.initialize()
		
	if event_manager and event_manager.has_method("initialize"):
		event_manager.initialize(state_manager)
		
	if task_manager and task_manager.has_method("initialize"):
		task_manager.initialize(state_manager)

	if ending_sequence_manager and ending_sequence_manager.has_method("initialize"):
		ending_sequence_manager.initialize(self, task_manager, state_manager)

	# Generate session password
	session_password = _generate_password()
	DebugLogger.info("GameManager", "Session password generated: " + session_password)
	
	systems_initialized = true
	DebugLogger.info("GameManager", "All systems initialized")

func start_game():
	"""Called when player starts the game from menu"""
	if game_is_running:
		DebugLogger.warning("GameManager", "Game already running, ignoring start_game call")
		return
		
	DebugLogger.info("GameManager", "Starting game - initializing all systems")
	
	# Reset everything first
	reset_game()
	
	# Initialize systems
	initialize_systems()
	
	# Mark game as running
	game_is_running = true
	
	# DON'T start day 1 here - wait for intro to finish
	emit_signal("game_started")

func start_first_day():
	"""Called after intro cutscene finishes"""
	if not game_is_running:
		DebugLogger.error("GameManager", "Cannot start first day - game not running")
		return
		
	if current_day != 0:
		DebugLogger.warn("GameManager", "First day already started")
		return
	
	# Start the event system now that game is actually beginning
	if event_manager and event_manager.has_method("start"):
		event_manager.start()
		
	start_day(1)

func start_new_day() -> void:
	start_day(current_day+1)

func start_day(day_number: int):
	"""Start a specific day"""
	if not game_is_running:
		DebugLogger.error("GameManager", "Cannot start day - game not running")
		return
		
	current_day = day_number
	DebugLogger.info("GameManager", "Starting day " + str(current_day))
	
	# Start the day in other managers
	if event_manager and event_manager.has_method("start_day"):
		event_manager.start_day(current_day)
		
	if task_manager and task_manager.has_method("start_day"):
		task_manager.start_day(current_day)
	
	emit_signal("day_started", current_day)
	DebugLogger.info("GameManager", "Day " + str(current_day) + " started successfully")

func end_day():
	"""End the current day"""
	if not game_is_running:
		return
		
	DebugLogger.info("GameManager", "Ending day " + str(current_day))
	
	# End day in other managers
	if event_manager and event_manager.has_method("end_day"):
		event_manager.end_day()
		
	if task_manager and task_manager.has_method("end_day"):
		task_manager.end_day()
	
	emit_signal("day_ended", current_day)
	
	# Check if we should continue or end game
	if current_day >= max_days:
		end_game()
	else:
		# Next day will be started by transition system
		pass

func end_game():
	"""End the game and return to menu"""
	if not game_is_running:
		return
		
	DebugLogger.info("GameManager", "Ending game")
	
	game_is_running = false
	emit_signal("game_ended")
	
	# Stop all systems
	stop_systems()
	
	# Transition to ending or menu
	if ending_sequence_manager:
		ending_sequence_manager.start_ending_sequence()
	else:
		# Return to main menu
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


# Helper method to get dream sequence handler from group
func get_dream_sequence_handler() -> DreamSequenceEventHandler:
	var handler = get_tree().get_first_node_in_group("dream_sequence_handler")
	return handler as DreamSequenceEventHandler

# Optional: Add this method to check if a dream sequence should play
func should_play_dream_sequence() -> bool:
	var handler = get_dream_sequence_handler()
	return current_day == 2 and handler != null

# Optional: Add debug method for testing dream sequence
func test_dream_sequence() -> void:
	var dream_handler = get_dream_sequence_handler()
	if not dream_handler:
		DebugLogger.error("GameManager", "No dream sequence handler found in group")
		return
		
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var interaction_comp = player.get_node("PlayerInteractionComponent")
		if interaction_comp:
			dream_handler.trigger_dream_sequence(interaction_comp)
		else:
			DebugLogger.error("GameManager", "No player interaction component found")
	else:
		DebugLogger.error("GameManager", "No player found")
		
func reset_game():
	"""Reset all game state"""
	DebugLogger.info("GameManager", "Resetting game state")
	
	current_day = 0
	game_is_running = false
	systems_initialized = false
	session_password = ""
	
	# Reset all managers
	if state_manager and state_manager.has_method("reset"):
		state_manager.reset()
		
	if event_manager and event_manager.has_method("reset"):
		event_manager.reset()
		
	if task_manager and task_manager.has_method("reset"):
		task_manager.reset()

func stop_systems():
	"""Stop all running systems"""
	DebugLogger.info("GameManager", "Stopping all systems")
	
	# Stop event processing
	if event_manager and event_manager.has_method("stop"):
		event_manager.stop()
		
	# Stop any other systems that need stopping
	if task_manager and task_manager.has_method("stop"):
		task_manager.stop()
		
	systems_initialized = false

func _generate_password() -> String:
	"""Generate a random 6-character password"""
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var password = ""
	for i in range(6):
		password += chars[randi() % chars.length()]
	return password

func is_game_running() -> bool:
	"""Check if game is currently running"""
	return game_is_running

func get_current_day() -> int:
	"""Get the current day number"""
	return current_day

func get_session_password() -> String:
	"""Get the current session password"""
	return session_password
