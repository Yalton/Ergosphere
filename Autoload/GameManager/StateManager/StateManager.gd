# StateManager.gd
extends Node
class_name StateManager

signal state_changed(state_name: String, new_value: Variant)

@export var enable_debug: bool = true
var module_name: String = "StateManager"

# Game states
var states: Dictionary = {
	"power": "on",
	"emergency_mode": false,
	"lockdown": false,
	"player_has_keycard": false,
	"main_door_open": false
}

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)

func initialize() -> void:
	DebugLogger.info(module_name, "StateManager initialized with states: " + str(states.keys()))

func set_state(state_name: String, value: Variant) -> void:
	if not states.has(state_name):
		DebugLogger.warning(module_name, "Unknown state: " + state_name)
		states[state_name] = value  # Create it anyway
	
	var old_value = states.get(state_name)
	states[state_name] = value
	
	DebugLogger.debug(module_name, "State changed: " + state_name + " from " + str(old_value) + " to " + str(value))
	
	state_changed.emit(state_name, value)

func get_state(state_name: String) -> Variant:
	if not states.has(state_name):
		DebugLogger.warning(module_name, "Unknown state requested: " + state_name)
		return null
		
	return states[state_name]

func has_state(state_name: String) -> bool:
	return states.has(state_name)

# Convenience methods
func is_power_on() -> bool:
	return get_state("power") == "on"

func is_emergency_mode() -> bool:
	return get_state("emergency_mode") == true

func is_lockdown() -> bool:
	return get_state("lockdown") == true

# Save/load state for persistence
func save_state() -> Dictionary:
	return states.duplicate()

func load_state(saved_states: Dictionary) -> void:
	for key in saved_states:
		set_state(key, saved_states[key])
