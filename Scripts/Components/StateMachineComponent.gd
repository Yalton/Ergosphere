class_name StateMachineComponent
extends Node

signal state_changed(new_state)

var current_state: int = 0
var states: Dictionary = {}

func add_state(state_name: String, state_id: int) -> void:
	states[state_name] = state_id

func set_state(new_state: int) -> void:
	current_state = new_state
	emit_signal("state_changed", current_state)

func get_state() -> int:
	return current_state

func get_state_name() -> String:
	for state_name in states.keys():
		if states[state_name] == current_state:
			return state_name
	return "Unknown"
