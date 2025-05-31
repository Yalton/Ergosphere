# WindowShutterLever.gd
extends GameObject

signal shutters_toggled(open_state: bool)
signal object_state_updated(interaction_text: String)

@export var enable_debug: bool = true
var module_name: String = "WindowShutterLever"

@export_group("Lever Settings")
@export var lever_animation_player: AnimationPlayer
@export var open_animation: String = "lever_open"
@export var close_animation: String = "lever_close"

@export_group("Shutter References")
@export var window_shutters: Node3D  # Reference to the window_shutters scene

@export_group("Interaction Settings")
@export var interaction_cooldown: float = 5.0

# Internal state
var shutters_open: bool = false  # Start closed (walls down)
var is_interacting: bool = false
var cooldown_timer: Timer

func _ready() -> void:
	super._ready()
	
	DebugLogger.register_module(module_name, enable_debug)
	
	# Set display name if not already set
	if display_name.is_empty():
		display_name = "Window Shutter Lever"
	
	# Create cooldown timer
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	add_child(cooldown_timer)
	
	# Set initial interaction text (shutters start closed)
	_update_interaction_text()
	
	DebugLogger.debug(module_name, "Window shutter lever initialized - shutters start closed")

func interact(player_interaction: PlayerInteractionComponent) -> void:
	if is_interacting or cooldown_timer.time_left > 0:
		DebugLogger.debug(module_name, "Lever on cooldown or already interacting")
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
		DebugLogger.error(module_name, "Window shutters reference not found or missing method")
	
	# Start cooldown
	_start_cooldown()
	
	# Update interaction text
	_update_interaction_text()
	
	# Emit signal
	shutters_toggled.emit(shutters_open)
	
	is_interacting = false
	
	DebugLogger.info(module_name, "Shutters " + ("opened" if shutters_open else "closed"))

func _start_cooldown() -> void:
	# Start cooldown timer
	cooldown_timer.start(interaction_cooldown)
	
	DebugLogger.debug(module_name, "Started cooldown for " + str(interaction_cooldown) + " seconds")

func _on_cooldown_finished() -> void:
	DebugLogger.debug(module_name, "Cooldown finished, lever ready for interaction")

func _update_interaction_text() -> void:
	var text = "Close shutters" if shutters_open else "Open shutters"
	object_state_updated.emit(text)
