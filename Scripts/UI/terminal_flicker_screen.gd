extends Control
class_name TerminalFlickerScreen

## Control node that displays glitched/corrupted text messages on terminals

@export_group("Message Settings")
## Array of possible messages to display
@export var glitch_messages: Array[String] = [
	"HELP ME",
	"IT SEES YOU", 
	"DON'T TRUST",
	"WAKE UP",
	"ERROR ERROR ERROR",
	"SYSTEM COMPROMISED",
	"NULL NULL NULL",
	"THEY ARE WATCHING",
	"RUN",
	"IT'S TOO LATE"
]

## Font to use for the message
@export var message_font: Font

## Message display settings
@export var font_size: int = 48
@export var text_color: Color = Color.GREEN
@export var glitch_color_1: Color = Color.RED
@export var glitch_color_2: Color = Color.CYAN

@export_group("Animation")
## How fast the text flickers between normal and glitched
@export var flicker_rate: float = 0.1
## Characters to use for glitching effect
@export var glitch_chars: String = "!@#$%^&*()_+-=[]{}|;:,.<>?/~`"

var current_message: String = ""
var glitched_message: String = ""
var label: Label
var flicker_timer: float = 0.0
var is_glitched: bool = false

func _ready() -> void:
	DebugLogger.register_module("TerminalFlickerScreen")
	
	# Create a label to display the message
	label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	if message_font:
		label.add_theme_font_override("font", message_font)
	label.add_theme_color_override("font_color", text_color)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	
	
	DebugLogger.debug("TerminalFlickerScreen", "Flicker screen initialized")

func show_message(message: String = "") -> void:
	# Use provided message or pick random one
	if message.is_empty():
		current_message = glitch_messages.pick_random()
	else:
		current_message = message
	
	# Generate glitched version
	glitched_message = _generate_glitched_text(current_message)
	
	# Start with the glitched version
	label.text = glitched_message
	is_glitched = true
	
	# Make visible
	visible = true
	
	DebugLogger.debug("TerminalFlickerScreen", "Showing message: " + current_message)

func _process(delta: float) -> void:
	if not visible:
		return
		
	flicker_timer += delta
	
	if flicker_timer >= flicker_rate:
		flicker_timer = 0.0
		is_glitched = !is_glitched
		
		if is_glitched:
			# Show glitched version with color variation
			label.text = glitched_message
			var color_choice = randf()
			if color_choice < 0.33:
				label.add_theme_color_override("font_color", glitch_color_1)
			elif color_choice < 0.66:
				label.add_theme_color_override("font_color", glitch_color_2)
			else:
				label.add_theme_color_override("font_color", text_color)
		else:
			# Show normal message
			label.text = current_message
			label.add_theme_color_override("font_color", text_color)

func _generate_glitched_text(text: String) -> String:
	var result = ""
	
	for c in text:
		if c == " ":
			result += " "
		elif randf() < 0.3:  # 30% chance to glitch each character
			result += glitch_chars[randi() % glitch_chars.length()]
		else:
			result += c
	
	return result
