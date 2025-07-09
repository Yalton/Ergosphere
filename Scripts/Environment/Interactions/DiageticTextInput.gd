class_name DiageticTextInputUI
extends DiegeticUIBase

## A diegetic UI that allows text input from the player.
## Forwards keyboard events to the SubViewport while maintaining ESC to exit.

signal exit_requested  # Signal that child UI can connect to

@export_group("Text Input Settings")
## If true, will capture all keyboard input except ESC while UI is active
@export var capture_keyboard_input: bool = true
## Optional sound to play when typing
@export var typing_sound: AudioStream
## Volume for typing sounds (-80 to 0 db)
@export var typing_sound_volume: float = -10.0

var typing_audio: AudioStreamPlayer3D

func _ready() -> void:
	super._ready()
	module_name = "DiageticTextInputUI"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Create audio player for typing sounds if sound is provided
	if typing_sound:
		typing_audio = AudioStreamPlayer3D.new()
		typing_audio.stream = typing_sound
		typing_audio.volume_db = typing_sound_volume
		typing_audio.max_distance = 10.0
		typing_audio.bus = "SFX"
		add_child(typing_audio)
		DebugLogger.debug(module_name, "Typing audio player created")
	
	DebugLogger.debug(module_name, "Text input UI initialized")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		DebugLogger.debug(module_name, "ESC pressed, ending interaction")
		end_interaction()
		get_viewport().set_input_as_handled()
		return
		
func _unhandled_input(event: InputEvent) -> void:
	if !is_player_interacting:
		return
	
	# Check for ESC to exit - try both "menu" and "ui_cancel" actions
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		DebugLogger.debug(module_name, "ESC pressed, ending interaction")
		end_interaction()
		get_viewport().set_input_as_handled()
		return
	
	# Remove the interact key check - we only want ESC to exit
	# This allows typing 'E' in text fields
	
	# Forward mouse wheel events to SubViewport
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if sub_viewport:
				sub_viewport.push_input(event)
				DebugLogger.debug(module_name, "Forwarded mouse wheel event to SubViewport")
			get_viewport().set_input_as_handled()
			return
	
	# Forward keyboard events to SubViewport if capture is enabled
	if capture_keyboard_input and event is InputEventKey:
		# Play typing sound for key presses (not releases)
		if event.pressed and typing_audio and not event.echo:
			typing_audio.play()
			DebugLogger.debug(module_name, "Playing typing sound")
		
		# Forward the keyboard event to the SubViewport
		if sub_viewport:
			sub_viewport.push_input(event)
			DebugLogger.debug(module_name, "Forwarded keyboard event: " + str(event.keycode))
		
		get_viewport().set_input_as_handled()
		return
	
	# Handle mouse events as before (from parent class)
	if !(event is InputEventMouseButton or event is InputEventMouseMotion):
		sub_viewport.push_input(event)

func start_interaction() -> void:
	super.start_interaction()

	# Show tab hint to player
	#HintSystem.show_hint("TAB: Swap selected UI element", 3.0)
	CommonUtils.send_player_hint("", "TAB: Swap selected UI element")

	DebugLogger.debug(module_name, "Showed tab navigation hint")
	
	# Additional setup for text input
	if capture_keyboard_input:
		DebugLogger.debug(module_name, "Keyboard input capture enabled")
	
	# Force focus grab when interaction starts
	call_deferred("_force_interaction_focus")
	
	# Connect exit signal to any child UI that might have an exit_terminal method
	if sub_viewport and sub_viewport.get_child_count() > 0:
		var ui = sub_viewport.get_child(0)
		if ui.has_method("_on_exit_requested"):
			exit_requested.connect(ui._on_exit_requested)
			DebugLogger.debug(module_name, "Connected exit signal to child UI")

func _force_interaction_focus() -> void:
	# Find the terminal UI in the SubViewport and force its input field to grab focus
	if sub_viewport and sub_viewport.get_child_count() > 0:
		var ui = sub_viewport.get_child(0)
		if ui.has_method("_force_focus_grab"):
			ui._force_focus_grab()
			DebugLogger.debug(module_name, "Forced focus grab on child UI input field")

func end_interaction() -> void:
	# Stop any playing typing sounds
	if typing_audio and typing_audio.playing:
		typing_audio.stop()
	
	# Disconnect exit signal if connected
	if sub_viewport and sub_viewport.get_child_count() > 0:
		var ui = sub_viewport.get_child(0)
		#if exit_requested.is_connected(ui._on_exit_requested):
			#exit_requested.disconnect(ui._on_exit_requested)
	
	super.end_interaction()
	
	DebugLogger.debug(module_name, "Text input interaction ended")

# Public method that child UI can call to request exit
func request_exit() -> void:
	DebugLogger.debug(module_name, "Exit requested from child UI")
	end_interaction()

# Override to handle day reset for text input specific stuff
func _on_day_reset_custom() -> void:
	# Could clear any text fields in the SubViewport UI here if needed
	DebugLogger.debug(module_name, "Day reset for text input UI")
	pass
