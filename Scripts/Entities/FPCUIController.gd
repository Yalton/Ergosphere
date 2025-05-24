class_name FPCUIController
extends Control

signal message_finished
signal interaction_changed(available: bool)

# Message panel references 
@export_group("Message System")
@export var message_panel: PanelContainer
@export var message_label: RichTextLabel
@export var message_speed: float = 0.02  # Time per character
@export var message_display_time: float = 3.0  # How long the message stays after typing
@export var typing_sound: AudioStream
@export var typing_sound_interval: int = 3  # Play sound every X characters

# Interaction prompt references
@export_group("Interaction System")
@export var interaction_panel: PanelContainer
@export var interaction_label: RichTextLabel
@export var interaction_icon: TextureRect

# Internal variables for message system
var is_message_completed: bool = false
var message_tween: Tween
var message_timer: Timer
var last_typing_position: int = 0

# Internal variables for interaction system
var current_interaction_text: String = ""
var is_interaction_available: bool = false

func _ready() -> void:
	# Setup initial state
	message_label.text = ""
	message_panel.hide()
	
	if interaction_panel:
		interaction_panel.hide()  # Make sure it's hidden initially
		interaction_icon.hide()
		
	# Create message hide timer
	message_timer = Timer.new()
	message_timer.one_shot = true
	message_timer.timeout.connect(_on_message_timer_timeout)
	add_child(message_timer)

#region Message System
func show_message(message_text: String) -> void:
	# Clear any existing timers and tweens
	if message_timer.time_left > 0:
		message_timer.stop()
	
	if message_tween and message_tween.is_valid():
		message_tween.kill()
	
	# Reset state
	is_message_completed = false
	last_typing_position = 0
	
	# Show panel and prepare empty text
	message_panel.show()
	message_label.text = ""
	
	# Create and start typing tween
	message_tween = create_tween()
	message_tween.set_trans(Tween.TRANS_LINEAR)
	
	var full_text_length = float(message_text.length())
	message_tween.tween_method(
		func(progress: float):
			var current_length = int(progress)
			
			# Play typing sound at intervals
			if typing_sound and current_length > 0:
				if current_length - last_typing_position >= typing_sound_interval:
					Audio.play_sound_with_random_pitch(typing_sound, 0.8, 1.2, true, -10.0, "SFX")
					last_typing_position = current_length
			
			# Update displayed text
			message_label.text = message_text.substr(0, current_length),
		0.0,
		full_text_length,
		message_speed * full_text_length
	)
	
	message_tween.finished.connect(func():
		is_message_completed = true
		message_label.text = message_text
		message_timer.start(message_display_time)
	)

# Show a message that stays visible until explicitly hidden
func show_persistent_message(message_text: String) -> void:
	# Clear any existing timers and tweens
	if message_timer.time_left > 0:
		message_timer.stop()
	
	if message_tween and message_tween.is_valid():
		message_tween.kill()
	
	# Show panel and set full text immediately
	message_panel.show()
	message_label.text = message_text
	is_message_completed = true
	
	# No timer - message will stay until hide_message() is called

# Show full message with optional auto-hide timer
func show_full_message(message_text: String, display_time: float = message_display_time) -> void:
	# Clear any existing timers and tweens
	if message_timer.time_left > 0:
		message_timer.stop()
	
	if message_tween and message_tween.is_valid():
		message_tween.kill()
	
	# Show panel and set full text immediately
	message_panel.show()
	message_label.text = message_text
	is_message_completed = true
	
	# Only start timer if display_time is positive
	if display_time > 0:
		message_timer.start(display_time)
	# Otherwise message will stay until hide_message() is called

# Explicitly hide the message
func hide_message() -> void:
	if message_timer.time_left > 0:
		message_timer.stop()
	
	message_panel.hide()
	message_finished.emit()

func _on_message_timer_timeout() -> void:
	message_panel.hide()
	message_finished.emit()

# Skip to the end of the current message
func skip_message() -> void:
	if message_tween and message_tween.is_valid():
		message_tween.kill()
		
	is_message_completed = true
	if message_label.text.length() > 0:
		message_timer.start(message_display_time)
#endregion

#region Interaction System

func show_interaction(text: String, icon: Texture2D = null) -> void:
	if not interaction_panel:
		return
		
	current_interaction_text = text
	
	# Update UI elements
	interaction_label.text = text
	
	if interaction_icon and icon:
		interaction_icon.texture = icon
		interaction_icon.show()
	elif interaction_icon:
		interaction_icon.hide()
	
	# Show the panel
	interaction_panel.show()
	interaction_icon.show()
	is_interaction_available = true
	interaction_changed.emit(true)

func hide_interaction() -> void:
	if interaction_panel:
		interaction_panel.hide()
		interaction_icon.hide()
		is_interaction_available = false
		current_interaction_text = ""
		interaction_changed.emit(false)

func is_interaction_showing() -> bool:
	return is_interaction_available

func get_current_interaction_text() -> String:
	return current_interaction_text
#endregion

# Useful for debugging or testing
func test_message(text: String = "This is a test message") -> void:
	show_message(text)

func test_interaction(text: String = "Test Interaction") -> void:
	show_interaction(text)
