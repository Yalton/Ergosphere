class_name PlayerUI
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

# Task UI references
@export_group("Task System")
@export var task_tree_ui: Tree  # Reference to the TaskTreeUI node
@export var task_panel: PanelContainer  # Optional container for the task tree

# Hint system references
@export_group("Hint System")
@export var hint_container: HBoxContainer  # The HintContainer in your scene
@export var hint_scene: PackedScene  # Scene with HintUI script
@export var enable_debug: bool = false
@export var hint_audio: AudioStreamPlayer3D

@export_group("Dev Console")
@export var dev_console_ui: DevConsoleUI  # Reference to the DevConsoleUI node

# Add to exports:
@export_group("Flashlight Meter")
## Progress bar or TextureProgress that shows flashlight battery
@export var flashlight_meter: ProgressBar
## Optional container to show/hide the entire meter UI
@export var flashlight_meter_container: Control

# Internal variables for message system
var is_message_completed: bool = false
var message_tween: Tween
var message_timer: Timer
var last_typing_position: int = 0

# Internal variables for interaction system
var current_interaction_text: String = ""
var is_interaction_available: bool = false

# Internal variables for hint system
var active_hints: Array = []
var module_name: String = "PlayerUI"

# Queue for messages/hints that arrive while paused
var queued_messages: Array = []
var queued_hints: Array = []

func _ready() -> void:
	# Register debug logger
	DebugLogger.register_module(module_name, enable_debug)
	
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
	
	# Setup dev console if available
	if dev_console_ui:
		DevConsoleManager.set_console_ui(dev_console_ui, true)
		DebugLogger.debug(module_name, "Dev console UI connected")
		
	GameManager.task_manager.task_completed.connect(_on_task_completed)
	# Connect to task tree UI if available
	if task_tree_ui:
		if task_tree_ui.has_signal("visibility_state_changed"):
			task_tree_ui.visibility_state_changed.connect(_on_task_visibility_changed)
	
	# Hide task panel initially if it exists
	if task_panel:
		task_panel.hide()
	
	# Hide hint container initially
	if hint_container:
		hint_container.hide()

	# Initialize flashlight meter
	if flashlight_meter:
		flashlight_meter.min_value = 0
		flashlight_meter.max_value = 100
		flashlight_meter.value = 100
		
		# Hide initially since battery starts full
		if flashlight_meter_container:
			flashlight_meter_container.hide()
		else:
			flashlight_meter.hide()
		
		DebugLogger.debug(module_name, "Flashlight meter initialized")


func _process(_delta: float) -> void:
	# Process queued messages when unpaused
	if not get_tree().paused and queued_messages.size() > 0:
		var msg = queued_messages.pop_front()
		_process_queued_message(msg)
	
	# Process queued hints when unpaused
	if not get_tree().paused and queued_hints.size() > 0:
		var hint = queued_hints.pop_front()
		_show_hint_internal(hint.type, hint.text)

#region Message System
func show_message(speaker_name: String, message_text: String) -> void:
	# Queue message if game is paused
	if get_tree().paused:
		queued_messages.append({
			"speaker": speaker_name,
			"text": message_text,
			"type": "normal"
		})
		DebugLogger.debug(module_name, "Message queued due to pause: " + message_text)
		return
	
	_show_message_with_typing(speaker_name, message_text)

func _show_message_with_typing(speaker_name: String, message_text: String) -> void:
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
			message_label.text = "[outline_size=2][outline_color=00ff00]" + speaker_name + " "  + message_text.substr(0, current_length)+ "[/outline_color][/outline_size]",
		0.0,
		full_text_length,
		message_speed * full_text_length
	)
	
	message_tween.finished.connect(func():
		is_message_completed = true
		message_label.text = "[outline_size=2][outline_color=00ff00]" + speaker_name + " "  + message_text + "[/outline_color][/outline_size]"
		message_timer.start(message_display_time)
	)

# Show a message that stays visible until explicitly hidden
func show_persistent_message(speaker_name: String, message_text: String) -> void:
	# Queue message if game is paused
	if get_tree().paused:
		queued_messages.append({
			"speaker": speaker_name,
			"text": message_text,
			"type": "persistent"
		})
		DebugLogger.debug(module_name, "Persistent message queued due to pause: " + message_text)
		return
	
	_show_persistent_message_internal(speaker_name, message_text)

func _show_persistent_message_internal(speaker_name: String, message_text: String) -> void:
	# Clear any existing timers and tweens
	if message_timer.time_left > 0:
		message_timer.stop()
	
	if message_tween and message_tween.is_valid():
		message_tween.kill()
	
	# Show panel and set full text immediately
	message_panel.show()
	message_label.text = "[outline_size=2][outline_color=00ff00]" + speaker_name + " "  + message_text + "[/outline_color][/outline_size]"
	is_message_completed = true
	
	# No timer - message will stay until hide_message() is called

# Show full message with optional auto-hide timer
func show_full_message(speaker_name: String, message_text: String, display_time: float = -1.0) -> void:
	# Queue message if game is paused
	if get_tree().paused:
		queued_messages.append({
			"speaker": speaker_name,
			"text": message_text,
			"type": "full",
			"display_time": display_time
		})
		DebugLogger.debug(module_name, "Full message queued due to pause: " + message_text)
		return
	
	_show_full_message_internal(speaker_name, message_text, display_time)

func _show_full_message_internal(speaker_name: String, message_text: String, display_time: float) -> void:
	# Clear any existing timers and tweens
	if message_timer.time_left > 0:
		message_timer.stop()
	
	if message_tween and message_tween.is_valid():
		message_tween.kill()
	
	# Show panel and set full text immediately
	message_panel.show()
	message_label.text = "[outline_size=2][outline_color=00ff00]" + speaker_name + " "  + message_text + "[/outline_color][/outline_size]"
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

# Process different message types from queue
func _process_queued_message(msg: Dictionary) -> void:
	match msg.type:
		"normal":
			_show_message_with_typing(msg.speaker, msg.text)
		"persistent":
			_show_persistent_message_internal(msg.speaker, msg.text)
		"full":
			var display_time = msg.get("display_time", -1.0)
			_show_full_message_internal(msg.speaker, msg.text, display_time)
#endregion

#region Interaction System

func show_interaction(text: String, icon: Texture2D = null) -> void:
	if not interaction_panel:
		return
		
	current_interaction_text = text
	
	# Update UI elements
	interaction_label.text = "[center][outline_size=2][outline_color=00ff00]" + text + "[/outline_color][/outline_size][/center]"
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

#region Hint System

func show_hint(type: String, hint_text: String) -> void:
	# Queue hint if game is paused
	if get_tree().paused:
		queued_hints.append({
			"type": type,
			"text": hint_text
		})
		DebugLogger.debug(module_name, "Hint queued due to pause: " + hint_text)
		return
	
	_show_hint_internal(type, hint_text)

func _show_hint_internal(type: String, hint_text: String) -> void:
	if not hint_container or not hint_scene:
		DebugLogger.error(module_name, "Hint system not configured properly")
		return
	
	# Create new hint instance
	var hint_instance = hint_scene.instantiate()
	if not hint_instance:
		DebugLogger.error(module_name, "Failed to instantiate hint scene")
		return
	
	match type: 
		"info": 
			hint_text = "Info: " + hint_text
		"warn":
			hint_text = "Warn: " + hint_text
		"emerg":
			hint_text = "Emerg: " + hint_text
		"cpl":
			hint_text = "Completed: " + hint_text
		_:
			hint_text = hint_text
	
	# Set the text
	hint_audio.play()
	hint_instance.set_hint_text(hint_text)
	
	# Add to container
	var vbox = hint_container.get_child(0)  # Assuming VBoxContainer is first child
	if vbox and vbox is VBoxContainer:
		vbox.add_child(hint_instance)
		active_hints.append(hint_instance)
		
		# Show container if it's hidden
		if not hint_container.visible:
			hint_container.show()
		
		# Connect to removal signal
		hint_instance.tree_exiting.connect(_on_hint_removed.bind(hint_instance))
		
		DebugLogger.debug(module_name, "Showed hint: " + hint_text)
	else:
		DebugLogger.error(module_name, "VBoxContainer not found in hint_container")
		hint_instance.queue_free()

func _on_hint_removed(hint_instance) -> void:
	active_hints.erase(hint_instance)
	
	# Hide container if no more hints
	if active_hints.is_empty() and hint_container:
		hint_container.hide()
		DebugLogger.debug(module_name, "All hints removed, hiding container")

func clear_all_hints() -> void:
	for hint in active_hints:
		if is_instance_valid(hint):
			hint.queue_free()
	
	active_hints.clear()
	
	if hint_container:
		hint_container.hide()
	
	DebugLogger.debug(module_name, "Cleared all hints")
#endregion

#region Task System

func _on_task_visibility_changed(local_is_visible: bool) -> void:
	if task_panel:
		task_panel.visible = local_is_visible
		DebugLogger.debug(module_name, "Task panel visibility changed: " + str(is_visible))

func show_task_panel() -> void:
	if task_panel:
		task_panel.show()
		DebugLogger.debug(module_name, "Task panel shown")

func hide_task_panel() -> void:
	if task_panel:
		task_panel.hide()
		DebugLogger.debug(module_name, "Task panel hidden")

func toggle_task_panel() -> void:
	if task_panel:
		task_panel.visible = !task_panel.visible
		DebugLogger.debug(module_name, "Task panel toggled to: " + str(task_panel.visible))


	
# Add this new adapter function:
func _on_task_completed(task_id: String) -> void:
	"""Adapter function to convert task_id String to BaseTask object"""
	if GameManager and GameManager.task_manager:
		var task = GameManager.task_manager.get_task(task_id)
		show_hint("cpl", task.task_name)
#endregion



# Add this new function to update the flashlight meter:
func update_flashlight_meter(battery_percentage: float, p_show: bool) -> void:
	"""Update the flashlight battery meter display
	Args:
		battery_percentage: Current battery level (0-100)
		show: Whether to show the meter
	"""
	if not flashlight_meter:
		return
	
	# Update the meter value
	flashlight_meter.value = battery_percentage

	# Show/hide the meter or its container
	if flashlight_meter_container:
		flashlight_meter_container.visible = p_show
	else:
		flashlight_meter.visible = p_show
	
	# Optional: Change meter color based on battery level
	if flashlight_meter.has_theme_stylebox_override("fill"):
		var fill_style = flashlight_meter.get_theme_stylebox("fill")
		if fill_style and fill_style is StyleBoxFlat:
			if battery_percentage <= 20:
				fill_style.bg_color = Color.RED
			elif battery_percentage <= 50:
				fill_style.bg_color = Color.YELLOW
			else:
				fill_style.bg_color = Color.GREEN
