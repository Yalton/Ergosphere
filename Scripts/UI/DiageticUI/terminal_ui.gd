extends DiageticUIContent

## Example terminal UI for use inside a DiageticTextInputUI SubViewport.
## This demonstrates a simple text input interface using DevConsoleManager.

signal terminal_exit_requested  # Signal to request closing the terminal

@export_group("UI References")
## The input field where player types
@export var input_field: LineEdit
## The output area showing terminal history
@export var output_area: RichTextLabel
## Optional label showing terminal name/title
@export var terminal_label: Label

@export_group("Terminal Settings")
## Terminal prompt character(s)
@export var prompt: String = "> "
## Maximum lines to keep in history
@export var max_history_lines: int = 100
## Terminal title/name
@export var terminal_name: String = "TERMINAL"

var command_history: Array[String] = []
var history_index: int = -1
var module_name: String = "TerminalUI"

func _ready() -> void:
	DebugLogger.register_module(module_name, false)
	
	# Set terminal name if label exists
	if terminal_label:
		terminal_label.text = terminal_name
	
	# Clear output area
	if output_area:
		output_area.clear()
		add_line("=== " + terminal_name + " ===")
		add_line("Connected to station systems")
		add_line("")
	
	# Setup input field
	if input_field:
		input_field.text_submitted.connect(_on_text_submitted)
		input_field.gui_input.connect(_on_input_gui_event)
		input_field.placeholder_text = "Enter command..."
	
	# Connect to DevConsoleManager output
	DevConsoleManager.output_requested.connect(_on_dev_console_output)
	
	# Force focus grab after a frame to ensure it works
	call_deferred("_force_focus_grab")
	
	DebugLogger.debug(module_name, "Terminal UI initialized with DevConsole integration")

func _force_focus_grab() -> void:
	if input_field:
		input_field.grab_focus()
		DebugLogger.debug(module_name, "Forced focus grab on input field")

func _on_text_submitted(text: String) -> void:
	if text.strip_edges() == "":
		return
	
	# Add to history
	command_history.append(text)
	history_index = command_history.size()
	
	# Display command with prompt
	add_line(prompt + text)
	
	# Set this terminal as the console UI for DevConsoleManager
	DevConsoleManager.set_console_ui(self, false)  # false = not admin mode
	
	# Process command through DevConsoleManager
	DevConsoleManager.process_command(text.strip_edges())
	
	# Clear input and keep focus
	if input_field:
		input_field.clear()
		input_field.grab_focus()

func _on_input_gui_event(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Navigate history with up/down arrows
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
	
	if input_field:
		if history_index < command_history.size():
			input_field.text = command_history[history_index]
			input_field.caret_column = input_field.text.length()
		else:
			input_field.clear()

func _on_dev_console_output(text: String, type: String) -> void:
	match type:
		"system":
			add_system_message(text)
		"error":
			add_error_message(text)
		"warning":
			add_warning_message(text)
		"normal", _:
			add_line(text)
	
	# Ensure input field keeps focus after any output
	if input_field and not input_field.has_focus():
		call_deferred("_refocus_input")

func _refocus_input() -> void:
	if input_field:
		input_field.grab_focus()
		DebugLogger.debug(module_name, "Refocused input field after console output")

# DevConsoleUI compatibility methods
func add_line(text: String, add_to_history: bool = true) -> void:
	if not output_area:
		return
	
	output_area.append_text(text + "\n")
	
	if add_to_history:
		# Limit history
		var lines = output_area.text.split("\n")
		if lines.size() > max_history_lines:
			var keep_lines = lines.slice(-max_history_lines)
			output_area.clear()
			output_area.append_text("\n".join(keep_lines))
	
	# Scroll to bottom
	output_area.scroll_to_line(output_area.get_line_count() - 1)
	
	# Re-grab focus on input field after adding output
	if input_field and not input_field.has_focus():
		call_deferred("_refocus_input")

func add_system_message(text: String) -> void:
	add_line("[color=#00ff00]" + text + "[/color]")

func add_error_message(text: String) -> void:
	add_line("[color=#ff0000]" + text + "[/color]")

func add_warning_message(text: String) -> void:
	add_line("[color=#ffff00]" + text + "[/color]")

func clear_console() -> void:
	if output_area:
		output_area.clear()
		add_line("=== " + terminal_name + " ===", false)

func hide_console() -> void:
	# Exit the terminal interface
	var parent_viewport = get_viewport()
	if parent_viewport and parent_viewport.get_parent() and parent_viewport.get_parent().has_method("request_exit"):
		parent_viewport.get_parent().request_exit()
