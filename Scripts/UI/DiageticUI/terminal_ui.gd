extends DiageticUIContent

## Example terminal UI for use inside a DiageticTextInputUI SubViewport.
## This demonstrates a simple text input interface.

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
		add_line("Type 'help' for commands")
		add_line("")
	
	# Setup input field
	if input_field:
		input_field.text_submitted.connect(_on_text_submitted)
		input_field.gui_input.connect(_on_input_gui_event)
		input_field.grab_focus()
		input_field.placeholder_text = "Enter command..."
	
	DebugLogger.debug(module_name, "Terminal UI initialized")

func _on_text_submitted(text: String) -> void:
	if text.strip_edges() == "":
		return
	
	# Add to history
	command_history.append(text)
	history_index = command_history.size()
	
	# Display command with prompt
	add_line(prompt + text)
	
	# Process command
	process_command(text.strip_edges())
	
	# Clear input and keep focus
	if input_field:
		input_field.clear()
		input_field.grab_focus()  # Keep focus on input field

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

func process_command(cmd: String) -> void:
	var parts = cmd.split(" ", false)
	if parts.is_empty():
		return
	
	var command = parts[0].to_lower()
	var args = parts.slice(1)
	
	match command:
		"help":
			show_help()
		"clear":
			clear_terminal()
		"echo":
			if args.size() > 0:
				add_line(" ".join(args))
			else:
				add_line("Usage: echo <text>")
		"time":
			add_line("Current time: " + Time.get_time_string_from_system())
		"exit", "quit":
			add_line("Goodbye!")
			# Call the parent DiageticTextInputUI's exit method
			var parent_viewport = get_viewport()
			if parent_viewport and parent_viewport.get_parent() and parent_viewport.get_parent().has_method("request_exit"):
				parent_viewport.get_parent().request_exit()
		_:
			add_line("Unknown command: " + command)
			add_line("Type 'help' for available commands")

func show_help() -> void:
	add_line("Available commands:")
	add_line("  help  - Show this help message")
	add_line("  clear - Clear terminal screen")
	add_line("  echo  - Echo text back")
	add_line("  time  - Show current time")
	add_line("  exit  - Exit terminal (or press ESC)")

func clear_terminal() -> void:
	if output_area:
		output_area.clear()
		add_line("=== " + terminal_name + " ===")

func add_line(text: String) -> void:
	if not output_area:
		return
	
	output_area.append_text(text + "\n")
	
	# Limit history
	var lines = output_area.text.split("\n")
	if lines.size() > max_history_lines:
		var keep_lines = lines.slice(-max_history_lines)
		output_area.clear()
		output_area.append_text("\n".join(keep_lines))
	
	# Scroll to bottom
	output_area.scroll_to_line(output_area.get_line_count() - 1)
