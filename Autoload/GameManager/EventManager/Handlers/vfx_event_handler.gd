extends EventHandler
class_name VFXEventHandler

## Handles all visual effects events: morse lights, brief flickers, fog, and glitches

# ============== MORSE LIGHT SETTINGS ==============
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

# ============== FOG SETTINGS ==============
@export_group("Fog Settings")
## Target fog density when active
@export var target_fog_density: float = 0.1
## Base time to fade in (seconds) - will be randomized
@export var base_fade_in_time: float = 20.0
## Base time to hold fog (seconds) - will be randomized  
@export var base_hold_time: float = 30.0
## Base time to fade out (seconds) - will be randomized
@export var base_fade_out_time: float = 20.0
## Time variation percentage (0.0-1.0) for randomization
@export var time_variation: float = 0.3

# ============== GLITCH SETTINGS ==============
@export_group("Glitch Settings")
## Duration range for the glitch effect in seconds
@export var min_glitch_duration: float = 2.0
@export var max_glitch_duration: float = 8.0
## Group name for diegetic UI elements that can be glitched
@export var diegetic_ui_group: String = "diegetic_ui"

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

# State tracking for morse light
var affected_light: Light3D = null
var original_energy: float = 0.0
var morse_sequence: Array = []
var is_transmitting: bool = false

# State tracking for fog
var world_environment: WorldEnvironment
var original_fog_density: float = 0.0
var fog_tween: Tween
var is_fog_active: bool = false

# State tracking for glitch
var glitched_ui: Node = null
var glitch_duration: float = 0.0

func _ready() -> void:
	# All events this consolidated handler processes
	handled_event_ids = [
		"morse_light",
		"brief_flicker", "brightness_boost",
		"fog", "fog_event",
		"terminal_glitch"
	]
	
	DebugLogger.register_module("VFXEventHandler")
	
	# Find world environment for fog effects
	_find_world_environment()

func _can_execute_internal() -> Dictionary:
	DebugLogger.log_message("VFXEventHandler", "Checking if can execute: " + event_data.id)
	
	match event_data.id:
		"morse_light":
			return _can_execute_morse()
		"brief_flicker", "purple_shift", "brightness_boost":
			return _can_execute_flicker()
		"fog", "fog_event":
			return _can_execute_fog()
		"terminal_glitch":
			return _can_execute_glitch()
		_:
			return {"success": false, "message": "Unknown event ID: " + event_data.id}

func _execute_internal() -> Dictionary:
	DebugLogger.log_message("VFXEventHandler", "Executing event: " + event_data.id)
	
	match event_data.id:
		"morse_light":
			return _execute_morse()
		"brief_flicker":
			return _execute_brief_flicker()
		"purple_shift":
			return _execute_purple_shift()
		"brightness_boost":
			return _execute_brightness_boost()
		"fog", "fog_event":
			return _execute_fog()
		"terminal_glitch":
			return _execute_glitch()
		_:
			return {"success": false, "message": "Unknown event ID: " + event_data.id}

func end() -> void:
	DebugLogger.log_message("VFXEventHandler", "Ending event: " + event_data.id)
	
	# Clean up based on event type
	match event_data.id:
		"morse_light":
			_end_morse()
		"fog", "fog_event":
			_end_fog()
		"terminal_glitch":
			_end_glitch()
		_:
			pass
	
	# Call base implementation
	super.end()

# ============== MORSE LIGHT FUNCTIONS ==============
func _can_execute_morse() -> Dictionary:
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if effects_manager and not effects_manager.power_is_on:
		return {"success": false, "message": "Power is off, cannot transmit morse code"}
	
	var nearest_light = _find_nearest_light()
	if not nearest_light:
		return {"success": false, "message": "No valid light found within " + str(max_light_distance) + " units of player"}
	
	if morse_messages.is_empty():
		return {"success": false, "message": "No morse messages configured"}
	
	return {"success": true, "message": "OK"}

func _execute_morse() -> Dictionary:
	affected_light = _find_nearest_light()
	if not affected_light:
		return {"success": false, "message": "No light found during execution"}
	
	original_energy = affected_light.light_energy
	
	var message = morse_messages.pick_random()
	morse_sequence = _text_to_morse_sequence(message)
	
	if morse_sequence.is_empty():
		return {"success": false, "message": "Failed to convert message to morse sequence"}
	
	is_transmitting = true
	_transmit_morse_sequence()
	
	return {"success": true, "message": "OK"}

func _find_nearest_light() -> Light3D:
	var player = CommonUtils.get_player()
	if not player:
		return null
	
	var lights = get_tree().get_nodes_in_group(lights_group)
	var nearest_light = null
	var nearest_distance = max_light_distance
	
	for light in lights:
		if not light is Light3D or not light.is_inside_tree():
			continue
		
		if not light.visible or light.light_energy <= 0:
			continue
		
		var distance = player.global_position.distance_to(light.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_light = light
	
	return nearest_light

func _text_to_morse_sequence(text: String) -> Array:
	var sequence = []
	
	for character in text.to_upper():
		if character in morse_dict:
			var morse = morse_dict[character]
			
			if sequence.size() > 0:
				if character == " ":
					sequence.append({"type": "gap", "duration": word_gap})
				else:
					sequence.append({"type": "gap", "duration": letter_gap})
			
			if character == " ":
				continue
			
			for i in range(morse.length()):
				var symbol = morse[i]
				
				if i > 0:
					sequence.append({"type": "gap", "duration": symbol_gap})
				
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
			_set_light_state(true)
		"gap":
			_set_light_state(false)
	
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

func _end_morse() -> void:
	is_transmitting = false
	
	if affected_light and is_instance_valid(affected_light):
		affected_light.light_energy = original_energy
	
	affected_light = null
	morse_sequence.clear()

# ============== BRIEF FLICKER FUNCTIONS ==============
func _can_execute_flicker() -> Dictionary:
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if not effects_manager:
		return {"success": false, "message": "No effects manager found in scene"}
	
	match event_data.id:
		"brief_flicker":
			if not effects_manager.has_method("trigger_brief_flicker"):
				return {"success": false, "message": "Effects manager missing trigger_brief_flicker method"}
		"purple_shift":
			if not effects_manager.has_method("trigger_purple_shift"):
				return {"success": false, "message": "Effects manager missing trigger_purple_shift method"}
		"brightness_boost":
			if not effects_manager.has_method("trigger_brightness_boost"):
				return {"success": false, "message": "Effects manager missing trigger_brightness_boost method"}
	
	return {"success": true, "message": "OK"}

func _execute_brief_flicker() -> Dictionary:
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if not effects_manager:
		return {"success": false, "message": "Could not find effects manager during execution"}
	
	effects_manager.trigger_brief_flicker()
	
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_active:
			end()
	)
	
	return {"success": true, "message": "OK"}

func _execute_purple_shift() -> Dictionary:
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if not effects_manager:
		return {"success": false, "message": "Could not find effects manager during execution"}
	
	effects_manager.trigger_purple_shift()
	
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_active:
			end()
	)
	
	return {"success": true, "message": "OK"}

func _execute_brightness_boost() -> Dictionary:
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if not effects_manager:
		return {"success": false, "message": "Could not find effects manager during execution"}
	
	effects_manager.trigger_brightness_boost()
	
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_active:
			end()
	)
	
	return {"success": true, "message": "OK"}

# ============== FOG FUNCTIONS ==============
func _find_world_environment() -> void:
	world_environment = get_tree().get_first_node_in_group("world_environment")
	if not world_environment:
		world_environment = _search_world_environment(get_tree().root)
	
	if world_environment and world_environment.environment:
		original_fog_density = world_environment.environment.volumetric_fog_density

func _search_world_environment(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
	
	for child in node.get_children():
		var result = _search_world_environment(child)
		if result:
			return result
	
	return null

func _can_execute_fog() -> Dictionary:
	if is_fog_active:
		return {"success": false, "message": "Fog event already active"}
	
	if not world_environment:
		return {"success": false, "message": "No WorldEnvironment found in scene"}
	
	if not world_environment.environment:
		return {"success": false, "message": "WorldEnvironment has no Environment resource"}
	
	return {"success": true, "message": "OK"}

func _execute_fog() -> Dictionary:
	is_fog_active = true
	
	var fade_in_time = _randomize_time(base_fade_in_time)
	var hold_time = _randomize_time(base_hold_time)
	var fade_out_time = _randomize_time(base_fade_out_time)
	
	_start_fog_sequence(fade_in_time, hold_time, fade_out_time)
	
	return {"success": true, "message": "OK"}

func _randomize_time(base_time: float) -> float:
	var variation = base_time * time_variation
	return base_time + randf_range(-variation, variation)

func _start_fog_sequence(fade_in_time: float, hold_time: float, fade_out_time: float) -> void:
	if fog_tween and fog_tween.is_valid():
		fog_tween.kill()
	
	fog_tween = create_tween()
	
	fog_tween.tween_method(_set_fog_density, original_fog_density, target_fog_density, fade_in_time)
	fog_tween.tween_interval(hold_time)
	fog_tween.tween_method(_set_fog_density, target_fog_density, original_fog_density, fade_out_time)
	fog_tween.tween_callback(_on_fog_sequence_complete)

func _set_fog_density(density: float) -> void:
	if world_environment and world_environment.environment:
		world_environment.environment.volumetric_fog_density = density

func _on_fog_sequence_complete() -> void:
	is_fog_active = false
	
	if is_active:
		end()

func _end_fog() -> void:
	if fog_tween and fog_tween.is_valid():
		fog_tween.kill()
	
	if world_environment and world_environment.environment:
		world_environment.environment.volumetric_fog_density = original_fog_density
	
	is_fog_active = false

# ============== GLITCH FUNCTIONS ==============
func _can_execute_glitch() -> Dictionary:
	var ui_elements = get_tree().get_nodes_in_group(diegetic_ui_group)
	if ui_elements.is_empty():
		return {"success": false, "message": "No diegetic UI elements found in group: " + diegetic_ui_group}
	
	var valid_elements = false
	for element in ui_elements:
		if element.has_method("corrupt_terminal"):
			valid_elements = true
			break
	
	if not valid_elements:
		return {"success": false, "message": "No UI elements with corrupt_terminal method found"}
	
	return {"success": true, "message": "OK"}

func _execute_glitch() -> Dictionary:
	var ui_elements = get_tree().get_nodes_in_group(diegetic_ui_group)
	
	if ui_elements.is_empty():
		return {"success": false, "message": "No diegetic UI elements found during execution"}
	
	var valid_elements = []
	for element in ui_elements:
		if element.has_method("corrupt_terminal"):
			valid_elements.append(element)
	
	if valid_elements.is_empty():
		return {"success": false, "message": "No UI elements with corrupt_terminal method available"}
	
	glitched_ui = valid_elements.pick_random()
	glitch_duration = randf_range(min_glitch_duration, max_glitch_duration)
	
	glitched_ui.corrupt_terminal()
	
	get_tree().create_timer(glitch_duration).timeout.connect(func():
		if is_active:
			end()
	)
	
	return {"success": true, "message": "OK"}

func _end_glitch() -> void:
	glitched_ui = null
