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
	
	# Clear output area and configure for proper scrolling
	if output_area:
		output_area.clear()
		output_area.fit_content = false  # CRITICAL - disable fit content so it doesn't expand
		output_area.scroll_active = true
		output_area.scroll_following = true  # Auto-follow new content
		output_area.focus_mode = Control.FOCUS_ALL
		
		add_line("=== " + terminal_name + " ===")
		add_line("Connected to station systems")
		add_line("")
	
	# Setup input field
	if input_field:
		input_field.text_submitted.connect(_on_text_submitted)
		input_field.gui_input.connect(_on_input_gui_event)
		input_field.placeholder_text = "Enter command..."
		input_field.focus_mode = Control.FOCUS_ALL
	
	# Connect to DevConsoleManager output
	DevConsoleManager.output_requested.connect(_on_dev_console_output)
	
	# Force focus grab after a frame to ensure it works
	call_deferred("_force_focus_grab")
	
	DebugLogger.debug(module_name, "Terminal UI initialized with DevConsole integration")

func _input(event: InputEvent) -> void:
	# Handle mouse wheel scrolling manually
	if event is InputEventMouseButton:
		if output_area and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				# Focus output area for scrolling if not already focused
				if not output_area.has_focus():
					output_area.grab_focus()
					DebugLogger.debug(module_name, "Auto-focused output area for scrolling")
				
				# Manually handle scrolling
				var scroll_bar = output_area.get_v_scroll_bar()
				var scroll_pixels = 50  # Pixels to scroll
				
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					# Scroll up
					scroll_bar.value = max(0, scroll_bar.value - scroll_pixels)
					DebugLogger.debug(module_name, "Scrolled up - bar value: %f" % scroll_bar.value)
				else:
					# Scroll down  
					scroll_bar.value = min(scroll_bar.max_value, scroll_bar.value + scroll_pixels)
					DebugLogger.debug(module_name, "Scrolled down - bar value: %f" % scroll_bar.value)
				
				get_viewport().set_input_as_handled()
				return
	
	# Auto-focus input field on typing alphanumeric or space
	if event is InputEventKey and event.pressed:
		var keycode = event.keycode
		var is_typing_key = false
		
		# Check for letters A-Z
		if keycode >= KEY_A and keycode <= KEY_Z:
			is_typing_key = true
		# Check for numbers 0-9 (both main keyboard and numpad)
		elif keycode >= KEY_0 and keycode <= KEY_9:
			is_typing_key = true
		elif keycode >= KEY_KP_0 and keycode <= KEY_KP_9:
			is_typing_key = true
		# Check for space
		elif keycode == KEY_SPACE:
			is_typing_key = true
		# Check for other common typing characters
		elif keycode in [KEY_PERIOD, KEY_COMMA, KEY_MINUS, KEY_EQUAL, KEY_SLASH, 
						  KEY_BACKSLASH, KEY_SEMICOLON, KEY_APOSTROPHE, KEY_BRACKETLEFT, 
						  KEY_BRACKETRIGHT, KEY_QUOTELEFT]:
			is_typing_key = true
		
		if is_typing_key:
			if input_field and not input_field.has_focus():
				input_field.grab_focus()
				DebugLogger.debug(module_name, "Auto-focused input field for typing")

func _force_focus_grab() -> void:
	if input_field:
		input_field.grab_focus()
		DebugLogger.debug(module_name, "Forced focus grab on input field")

func _on_text_submitted(text: String) -> void:
	if text.strip_edges() == "":
		# Even on empty submit, keep focus
		if input_field:
			input_field.grab_focus()
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
	
	# Clear input and FORCE focus back
	if input_field:
		input_field.clear()
		# Use call_deferred to ensure focus happens after all processing
		call_deferred("_ensure_input_focus")

func _ensure_input_focus() -> void:
	if input_field:
		input_field.grab_focus()
		DebugLogger.debug(module_name, "Re-focused input after command submission")

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
	
	# After console output, ensure input field has focus
	call_deferred("_ensure_input_focus")

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
