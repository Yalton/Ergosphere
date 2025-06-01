# EventResource.gd
extends Resource
class_name EventResource

@export var event_id: String = ""
@export var event_name: String = "Unnamed Event"
@export var event_description: String = ""

# Trigger settings
@export_enum("Time", "Task", "Location", "Random") var trigger_type: int = 0
@export var trigger_time: float = 0.0  # Time of day in seconds
@export var trigger_task_id: String = ""  # Task that triggers this
@export var trigger_location_group: String = ""  # Area group name
@export var random_chance: float = 0.1  # Chance per minute if random

# Event effects
@export var state_changes: Dictionary = {}  # States to set when event starts
@export var emergency_task_id: String = ""  # Emergency task to create
@export var affected_object_groups: Array[String] = []  # Groups to notify

# Requirements
@export var required_states: Dictionary = {}  # States needed to trigger

# Audio/Visual
@export var event_sound: AudioStream
@export var event_color: Color = Color.WHITE

func can_trigger(state_manager: StateManager) -> bool:
	for state_key in required_states:
		if state_manager.get_state(state_key) != required_states[state_key]:
			return false
	return true
