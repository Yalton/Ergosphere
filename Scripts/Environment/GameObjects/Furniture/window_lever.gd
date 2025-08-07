# WindowShutterLever.gd
extends GameObject

signal shutters_toggled(open_state: bool)
signal object_state_updated(interaction_text: String)

var module_name: String = "WindowShutterLever"

@export_group("Lever Settings")
## Animation player for lever animations
@export var lever_animation_player: AnimationPlayer
## Animation name for opening shutters
@export var open_animation: String = "lever_open"
## Animation name for closing shutters
@export var close_animation: String = "lever_close"

@export_group("Shutter References")
## Reference to the window_shutters scene
@export var window_shutters: Node3D

@export_group("Interaction Settings")
## Cooldown time after using lever
@export var interaction_cooldown: float = 5.0
## Time to wait after closing shutters for hawking before assigning open task again
@export var reopen_delay_after_hawking: float = 15.0

# Internal state
var shutters_open: bool = false  # Start closed
var is_interacting: bool = false
var cooldown_timer: Timer
var reopen_timer: Timer
var allowed_task_id: String = ""  # Task that allows interaction

func _ready() -> void:
	super._ready()
	
	DebugLogger.register_module(module_name)
	
	# Set display name if not already set
	if display_name.is_empty():
		display_name = "Window Shutter Lever"
	
	# Create cooldown timer
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	add_child(cooldown_timer)
	
	# Create reopen timer
	reopen_timer = Timer.new()
	reopen_timer.one_shot = true
	reopen_timer.timeout.connect(_on_reopen_timer_finished)
	add_child(reopen_timer)
	
	# Connect to task manager signals
	if GameManager.task_manager:
		GameManager.task_manager.task_assigned.connect(_on_task_assigned)
		GameManager.task_manager.task_completed.connect(_on_task_completed)
		DebugLogger.log_message(module_name, "Connected to task manager")
	
	# Set initial interaction text
	_update_interaction_text()
	
	DebugLogger.log_message(module_name, "Window shutter lever initialized - shutters closed")

func _on_task_assigned(task_id: String) -> void:
	# Check if this is a task that allows lever interaction
	if task_id == "open_shutters" and not shutters_open:
		allowed_task_id = task_id
		_update_interaction_text()
		DebugLogger.log_message(module_name, "Open shutters task assigned - lever enabled")
	elif task_id == "hawking_radiation" and shutters_open:
		allowed_task_id = task_id
		_update_interaction_text()
		DebugLogger.log_message(module_name, "Hawking radiation task assigned - lever enabled for closing")

func _on_task_completed(task_id: String) -> void:
	# Check if hawking radiation was just completed (shutters closed)
	if task_id == "hawking_radiation":
		DebugLogger.log_message(module_name, "Hawking radiation avoided - starting reopen timer")
		# Start timer to assign open_shutters task again
		reopen_timer.start(reopen_delay_after_hawking)
		allowed_task_id = ""
		_update_interaction_text()
	# Clear allowed task if it was completed
	elif task_id == allowed_task_id:
		allowed_task_id = ""
		_update_interaction_text()
		DebugLogger.log_message(module_name, "Task completed - lever disabled")

func _on_reopen_timer_finished() -> void:
	DebugLogger.log_message(module_name, "Reopen timer finished - assigning open_shutters task")
	
	# Assign the open shutters task again
	if GameManager.task_manager:
		GameManager.task_manager.assign_mandatory_tasks(["open_shutters"])
		DebugLogger.log_message(module_name, "Assigned open_shutters task after hawking delay")

func interact(_player_interaction: PlayerInteractionComponent) -> void:
	# Check if interaction is allowed
	if allowed_task_id.is_empty():
		DebugLogger.log_message(module_name, "No task allows lever interaction")
		return
	
	if is_interacting or cooldown_timer.time_left > 0:
		DebugLogger.log_message(module_name, "Lever on cooldown or already interacting")
		return
	
	is_interacting = true
	
	# Determine which animation to play
	var animation_to_play = close_animation if shutters_open else open_animation
	
	# Play lever animation
	if lever_animation_player and lever_animation_player.has_animation(animation_to_play):
		lever_animation_player.play(animation_to_play)
		
		# Wait for animation to finish
		if not lever_animation_player.is_connected("animation_finished", _on_animation_finished):
			lever_animation_player.animation_finished.connect(_on_animation_finished)
	else:
		# No animation, toggle shutters immediately
		_toggle_shutters()

func _on_animation_finished(anim_name: String) -> void:
	var expected_anim = close_animation if shutters_open else open_animation
	if anim_name == expected_anim:
		_toggle_shutters()

func _toggle_shutters() -> void:
	# Toggle state
	shutters_open = not shutters_open
	
	# Tell shutters to open/close
	if window_shutters and window_shutters.has_method("set_shutters_state"):
		window_shutters.set_shutters_state(shutters_open)
	else:
		DebugLogger.log_message(module_name, "Window shutters reference not found or missing method")
	
	# Complete the appropriate task
	if GameManager.task_manager:
		if allowed_task_id == "open_shutters" and shutters_open:
			GameManager.task_manager.complete_task("open_shutters")
			DebugLogger.log_message(module_name, "Completed open_shutters task")
		elif allowed_task_id == "hawking_radiation" and not shutters_open:
			GameManager.task_manager.complete_task("hawking_radiation")
			DebugLogger.log_message(module_name, "Completed hawking_radiation task")
	
	# Clear allowed task after completion
	allowed_task_id = ""
	
	# Start cooldown
	_start_cooldown()
	
	# Update interaction text
	_update_interaction_text()
	
	# Emit signal
	shutters_toggled.emit(shutters_open)
	
	is_interacting = false
	
	DebugLogger.log_message(module_name, "Shutters " + ("opened" if shutters_open else "closed"))

func _start_cooldown() -> void:
	cooldown_timer.start(interaction_cooldown)
	DebugLogger.log_message(module_name, "Started cooldown for " + str(interaction_cooldown) + " seconds")

func _on_cooldown_finished() -> void:
	DebugLogger.log_message(module_name, "Cooldown finished")
	_update_interaction_text()

func _update_interaction_text() -> void:
	var text = ""
	
	if cooldown_timer.time_left > 0:
		text = "Lever cooling down..."
	elif allowed_task_id == "open_shutters":
		text = "Open shutters"
	elif allowed_task_id == "hawking_radiation":
		text = "Close shutters (EMERGENCY)"
	elif not allowed_task_id.is_empty():
		text = "Use lever"
	else:
		text = "Lever (No task)"
	
	object_state_updated.emit(text)
	
	# Update interaction component if we have one
	if has_node("InteractionComponent"):
		var interaction = get_node("InteractionComponent")
		interaction.is_disabled = allowed_task_id.is_empty() or cooldown_timer.time_left > 0
		interaction.interaction_text = text
