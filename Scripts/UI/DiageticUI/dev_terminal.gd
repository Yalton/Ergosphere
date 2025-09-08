extends Control
class_name DevConsoleUI

## The dev console UI - displays command output and handles input
@export var output_label: RichTextLabel
@export var input_field: LineEdit
@export var scroll_container: ScrollContainer
## Maximum number of lines to keep in console history
@export var max_lines: int = 100
## Color for system messages in console
@export var system_color: Color = Color.GREEN
## Color for error messages in console
@export var error_color: Color = Color.RED
## Color for warning messages in console
@export var warning_color: Color = Color.YELLOW
## Enable debug logging for this module
@export var enable_debug: bool = true

@export var enable_terminal: bool = true

signal console_opened
signal console_closed

var console_history: Array[String] = []
var command_history: Array[String] = []
var history_index: int = -1
var module_name: String = "DevConsoleUI"
var was_mouse_captured: bool = false

func _ready() -> void:
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	
	# Initially hide
	visible = false
	
	# Connect input field signals
	if input_field:
		input_field.text_submitted.connect(_on_input_submitted)
		input_field.gui_input.connect(_on_input_gui_input)
	
	# Clear output on start
	if output_label:
		output_label.text = ""
	
	# Connect to DevConsoleManager's output signal
	DevConsoleManager.output_requested.connect(_on_output_requested)
	
	# Add welcome message
	add_line("[color=#%s]Dev Console v1.0[/color]" % system_color.to_html(), false)
	add_line("[color=#%s]Type 'help' for available commands[/color]" % system_color.to_html(), false)
	
	DebugLogger.debug(module_name, "Dev Console UI initialized")

func _input(event: InputEvent) -> void:
	if enable_terminal: 
		# Toggle console with backtick
		if event.is_action_pressed("toggle_dev_console"):
			toggle_console()
			get_viewport().set_input_as_handled()

func toggle_console() -> void:
	if visible:
		hide_console()
	else:
		show_console()

func show_console() -> void:
	if visible:
		return
	
	# Remember current mouse state
	was_mouse_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	
	# Show mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Show the console
	visible = true
	
	# Focus input field
	if input_field:
		input_field.grab_focus()
		input_field.clear()
	
	console_opened.emit()
	DebugLogger.debug(module_name, "Console opened")

func hide_console() -> void:
	if not visible:
		return
	
	# Hide the console
	visible = false
	
	# Clear input field
	if input_field:
		input_field.clear()
	
	# Restore mouse mode if it was captured
	if was_mouse_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	console_closed.emit()
	DebugLogger.debug(module_name, "Console closed")

func _on_input_submitted(text: String) -> void:
	if text.strip_edges() == "":
		return
	
	# Add command to history
	command_history.append(text)
	history_index = command_history.size()
	
	# Display the command in console
	add_line("> " + text)
	
	# Set this console UI as active in DevConsoleManager
	DevConsoleManager.set_console_ui(self, true)
	
	# Process the command
	DevConsoleManager.process_command(text)
	
	# Clear input
	input_field.clear()

func _on_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Navigate command history with up/down arrows
		if event.keycode == KEY_UP:
			navigate_history(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			navigate_history(1)
			get_viewport().set_input_as_handled()

func navigate_history(direction: int) -> void:
	if command_history.is_empty():
		return
	
	history_index = clamp(history_index + direction, 0, command_history.size())
	
	if history_index < command_history.size():
		input_field.text = command_history[history_index]
		input_field.caret_column = input_field.text.length()
	else:
		input_field.clear()

func _on_output_requested(text: String, type: String) -> void:
	# Handle output from DevConsoleManager
	match type:
		"system":
			add_system_message(text)
		"error":
			add_error_message(text)
		"warning":
			add_warning_message(text)
		_:
			add_line(text)
	
	DebugLogger.debug(module_name, "Output received: [%s] %s" % [type, text])

func add_line(text: String, use_bbcode: bool = true) -> void:
	if not output_label:
		return
	
	# Add timestamp
	var time = Time.get_time_string_from_system()
	var line = "[%s] %s" % [time, text]
	
	console_history.append(line)
	
	# Limit history size
	while console_history.size() > max_lines:
		console_history.pop_front()
	
	# Update display
	if use_bbcode:
		output_label.text = "\n".join(console_history)
	else:
		output_label.text = "\n".join(console_history)
	
	# Scroll to bottom
	if scroll_container:
		await get_tree().process_frame
		scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

func add_system_message(text: String) -> void:
	add_line("[color=#%s]%s[/color]" % [system_color.to_html(), text])

func add_error_message(text: String) -> void:
	add_line("[color=#%s]ERROR: %s[/color]" % [error_color.to_html(), text])

func add_warning_message(text: String) -> void:
	add_line("[color=#%s]WARNING: %s[/color]" % [warning_color.to_html(), text])

func clear_console() -> void:
	console_history.clear()
	if output_label:
		output_label.text = ""
	add_system_message("Console cleared")

func is_console_open() -> bool:
	return visible
