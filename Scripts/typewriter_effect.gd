
extends RichTextLabel

class_name TypewriterEffect

signal typing_completed
signal line_completed
signal screen_cleared

@export_category("Typing Settings")
@export var auto_start: bool = true
@export var letter_time: float = 0.05  # Time between typing each letter
@export var line_pause_time: float = 0.5  # Pause time after completing a line
@export var clear_pause_time: float = 0.5  # Time to show clear separator before clearing
@export var clear_after_lines: int = 10  # Clear screen after this many lines
@export var text_color: Color = Color("lime")  # Default color of the text
@export_multiline var test_lines: Array[String] = []  # For testing in the editor
@export var loop_test_lines: bool = false  # Loop through test lines when testing

@export_category("Audio")
@export var typing_sound: AudioStream  # Sound to play while typing
@export var typing_sound_interval: int = 3  # Play sound every X characters

# Internal variables
var _current_lines: Array[String] = []  # Lines queued for typing
var _current_line_index: int = 0  # Current line being typed
var _typed_lines_count: int = 0  # Count of fully typed lines
var _is_typing: bool = false  # Is currently typing
var _current_letter_index: int = 0  # Current position in the raw line being typed
var _typing_paused: bool = false  # Temporarily pause typing
var _last_sound_char: int = 0  # Last character index where sound was played
var _current_display_text: String = ""  # The complete text to display (with bbcode)

var _typing_timer: Timer
var _pause_timer: Timer
var _audio_player: AudioStreamPlayer

func _ready() -> void:
	# Register with DebugLogger if available
	if Engine.has_singleton("DebugLogger"):
		DebugLogger.register_module("TypewriterEffect", true)
	
	# Set up timers
	_typing_timer = Timer.new()
	_typing_timer.one_shot = true
	_typing_timer.timeout.connect(_on_typing_timer_timeout)
	add_child(_typing_timer)
	
	_pause_timer = Timer.new()
	_pause_timer.one_shot = true
	_pause_timer.timeout.connect(_on_pause_timer_timeout)
	add_child(_pause_timer)
	
	# Set up audio player
	if typing_sound:
		_audio_player = AudioStreamPlayer.new()
		_audio_player.stream = typing_sound
		_audio_player.bus = "SFX"
		add_child(_audio_player)
	
	# Initial setup
	clear_text()
	
	# Start if auto_start is enabled and we have test lines
	if auto_start and test_lines.size() > 0:
		set_lines(test_lines)
		start_typing()

func set_lines(lines: Array[String]) -> void:
	_current_lines = lines
	_current_line_index = 0
	_typed_lines_count = 0
	DebugLogger.debug("TypewriterEffect", "Set " + str(lines.size()) + " lines for typing")

func add_line(line: String) -> void:
	_current_lines.append(line)
	DebugLogger.debug("TypewriterEffect", "Added line: " + line)

func add_lines(lines: Array[String]) -> void:
	_current_lines.append_array(lines)
	DebugLogger.debug("TypewriterEffect", "Added " + str(lines.size()) + " lines")

func start_typing() -> void:
	if _current_lines.size() <= 0:
		DebugLogger.warning("TypewriterEffect", "Cannot start typing - no lines available")
		return
	
	_is_typing = true
	_type_next_character()
	DebugLogger.debug("TypewriterEffect", "Started typing process")

func stop_typing() -> void:
	_is_typing = false
	if _typing_timer.is_inside_tree():
		_typing_timer.stop()
	if _pause_timer.is_inside_tree():
		_pause_timer.stop()
	DebugLogger.debug("TypewriterEffect", "Stopped typing process")

func pause_typing() -> void:
	_typing_paused = true
	DebugLogger.debug("TypewriterEffect", "Paused typing")

func resume_typing() -> void:
	_typing_paused = false
	if _is_typing:
		_typing_timer.start(letter_time)
	DebugLogger.debug("TypewriterEffect", "Resumed typing")

func clear_text() -> void:
	text = ""
	_current_display_text = ""
	_current_letter_index = 0
	DebugLogger.debug("TypewriterEffect", "Cleared text")

func _type_next_character() -> void:
	if !_is_typing or _typing_paused:
		return
	
	if _current_line_index >= _current_lines.size():
		# If looping test lines, reset to beginning
		if loop_test_lines and test_lines.size() > 0:
			_current_lines = test_lines
			_current_line_index = 0
			_typed_lines_count = 0
		else:
			# Otherwise, we're done typing
			DebugLogger.debug("TypewriterEffect", "Typing completed")
			typing_completed.emit()
			return
	
	# Get the current line being typed
	var current_raw_line = _current_lines[_current_line_index]
	
	# If we're starting a new line, prepare it with full BBCode
	if _current_letter_index == 0:
		# Create a formatted version with BBCode at the beginning and end
		var formatted_line = "[center][color=#" + text_color.to_html(false) + "]" + current_raw_line + "[/color][/center]"
		
		# If this isn't the first line, add a newline before it
		if _typed_lines_count > 0:
			_current_display_text += "\n"
		
		# Add the opening tags to the display immediately (don't type them out)
		_current_display_text += "[center][color=#" + text_color.to_html(false) + "]"
	
	# Check if we've typed all characters in the current line
	if _current_letter_index < current_raw_line.length():
		# Add the next character to our display text
		_current_display_text += current_raw_line[_current_letter_index]
		_current_letter_index += 1
		
		# Play typing sound at intervals
		if _audio_player and _current_letter_index - _last_sound_char >= typing_sound_interval:
			_audio_player.pitch_scale = randf_range(0.95, 1.05)
			_audio_player.play()
			_last_sound_char = _current_letter_index
		
		# Update the visible text with all formatting
		text = _current_display_text + "[/color][/center]"
		
		# Schedule the next character
		_typing_timer.start(letter_time)
	else:
		# Line is complete, close the formatting tags
		_current_display_text += "[/color][/center]"
		text = _current_display_text
		
		# Reset for next line
		_current_letter_index = 0
		_current_line_index += 1
		_typed_lines_count += 1
		
		DebugLogger.debug("TypewriterEffect", "Line completed: " + str(_typed_lines_count))
		line_completed.emit()
		
		# Check if we need to clear the screen
		if _typed_lines_count >= clear_after_lines:
			_show_clear_screen()
		else:
			# Pause before the next line
			_pause_timer.start(line_pause_time)
			DebugLogger.debug("TypewriterEffect", "Pausing between lines")

func _show_clear_screen() -> void:
	DebugLogger.debug("TypewriterEffect", "Showing clear screen separator")
	
	# Replace content with separator line
	var separator = "[center][color=#" + text_color.to_html(false) + "]" + "-".repeat(100) + "[/color][/center]"
	_current_display_text = separator
	text = separator
	
	# Reset counters
	_typed_lines_count = 0
	
	# Schedule the actual clear
	_pause_timer.start(clear_pause_time)
	
	# Signal that screen is being cleared
	screen_cleared.emit()

func _on_typing_timer_timeout() -> void:
	if _is_typing and !_typing_paused:
		_type_next_character()

func _on_pause_timer_timeout() -> void:
	if _typed_lines_count == 0:
		# This timeout is for clearing the screen
		clear_text()
	
	# Continue typing
	if _is_typing and !_typing_paused:
		_type_next_character()

# Convenience function to add a formatted line and start typing if needed
func print_line(line: String) -> void:
	add_line(line)
	if !_is_typing:
		start_typing()
