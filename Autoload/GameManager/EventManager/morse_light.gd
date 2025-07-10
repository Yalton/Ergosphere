extends EventHandler
class_name MorseLightEvent

## Event that flickers a nearby light in morse code pattern

@export_group("Morse Settings")
## Messages to send via morse code
@export var morse_messages: Array[String] = [
	"SOS",
	"HELP",
	"RUN", 
	"WAKE",
	"STOP"
]
## Duration of a dot in seconds
@export var dot_duration: float = 0.2
## Duration of a dash (3x dot)
@export var dash_duration: float = 0.6
## Gap between dots/dashes within a letter
@export var symbol_gap: float = 0.2
## Gap between letters
@export var letter_gap: float = 0.6
## Gap between words
@export var word_gap: float = 1.4

@export_group("Light Settings")
## Maximum distance to find a light from the player
@export var max_light_distance: float = 15.0
## Group name for lights
@export var lights_group: String = "lights"
## How much to dim the light during "off" periods (0 = completely off)
@export var dim_factor: float = 0.1

# Morse code dictionary
var morse_dict = {
	"A": ".-", "B": "-...", "C": "-.-.", "D": "-..", "E": ".", 
	"F": "..-.", "G": "--.", "H": "....", "I": "..", "J": ".---",
	"K": "-.-", "L": ".-..", "M": "--", "N": "-.", "O": "---",
	"P": ".--.", "Q": "--.-", "R": ".-.", "S": "...", "T": "-",
	"U": "..-", "V": "...-", "W": ".--", "X": "-..-", "Y": "-.--",
	"Z": "--..", "0": "-----", "1": ".----", "2": "..---", "3": "...--",
	"4": "....-", "5": ".....", "6": "-....", "7": "--...", "8": "---..",
	"9": "----.", " ": " "
}

var affected_light: Light3D = null
var original_energy: float = 0.0
var morse_sequence: Array = []
var is_transmitting: bool = false

func _ready() -> void:
	super._ready()
	module_name = "MorseLightEvent"
	
	# Define which events this handler processes
	handled_event_ids = ["morse_light", "light_morse", "morse_code"]
	
	DebugLogger.debug(module_name, "MorseLightEvent ready")

func can_execute() -> bool:
	# First check base requirements
	if not super.can_execute():
		return false
	
	# Check if power is on
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if effects_manager and not effects_manager.power_is_on:
		DebugLogger.warning(module_name, "Power is off, cannot transmit morse")
		return false
	
	# Find nearest light to player
	var nearest_light = _find_nearest_light()
	if not nearest_light:
		DebugLogger.warning(module_name, "No valid light found near player")
		return false
	
	return true

func execute() -> bool:
	# Call base implementation
	if not super.execute():
		return false
	
	# Find nearest light
	affected_light = _find_nearest_light()
	if not affected_light:
		DebugLogger.error(module_name, "No light found during execution")
		return false
	
	# Store original energy
	original_energy = affected_light.light_energy
	
	# Pick random message
	var message = morse_messages.pick_random()
	DebugLogger.info(module_name, "Transmitting morse message '" + message + "' on light: " + affected_light.name)
	
	# Convert message to morse sequence
	morse_sequence = _text_to_morse_sequence(message)
	
	# Start transmission
	is_transmitting = true
	_transmit_morse_sequence()
	
	return true

func _find_nearest_light() -> Light3D:
	var player = GameManager.get_player()
	if not player:
		return null
	
	var lights = get_tree().get_nodes_in_group(lights_group)
	var nearest_light = null
	var nearest_distance = max_light_distance
	
	for light in lights:
		if not light is Light3D or not light.is_inside_tree():
			continue
		
		# Skip if light is not visible/enabled
		if not light.visible or light.light_energy <= 0:
			continue
		
		var distance = player.global_position.distance_to(light.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_light = light
	
	return nearest_light

func _text_to_morse_sequence(text: String) -> Array:
	var sequence = []
	
	for char in text.to_upper():
		if char in morse_dict:
			var morse = morse_dict[char]
			
			# Add letter gap if not first character
			if sequence.size() > 0:
				if char == " ":
					sequence.append({"type": "gap", "duration": word_gap})
				else:
					sequence.append({"type": "gap", "duration": letter_gap})
			
			# Skip spaces (gap already added)
			if char == " ":
				continue
			
			# Add morse symbols
			for i in range(morse.length()):
				var symbol = morse[i]
				
				# Add symbol gap if not first symbol
				if i > 0:
					sequence.append({"type": "gap", "duration": symbol_gap})
				
				# Add dot or dash
				if symbol == ".":
					sequence.append({"type": "on", "duration": dot_duration})
				elif symbol == "-":
					sequence.append({"type": "on", "duration": dash_duration})
	
	return sequence

func _transmit_morse_sequence() -> void:
	if not is_transmitting or morse_sequence.is_empty():
		end()
		return
	
	var current_symbol = morse_sequence.pop_front()
	
	match current_symbol.type:
		"on":
			# Turn light on
			_set_light_state(true)
		"gap":
			# Turn light off
			_set_light_state(false)
	
	# Wait for duration then process next symbol
	get_tree().create_timer(current_symbol.duration).timeout.connect(
		_transmit_morse_sequence
	)

func _set_light_state(on: bool) -> void:
	if not affected_light:
		return
	
	if on:
		affected_light.light_energy = original_energy
	else:
		affected_light.light_energy = original_energy * dim_factor

func end() -> void:
	is_transmitting = false
	
	# Restore light to original state
	if affected_light and is_instance_valid(affected_light):
		affected_light.light_energy = original_energy
		DebugLogger.info(module_name, "Morse transmission completed on light: " + affected_light.name)
	
	affected_light = null
	morse_sequence.clear()
	
	# Call base implementation
	super.end()
