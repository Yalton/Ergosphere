# StateAwareComponent.gd
extends Node
class_name StateAwareComponent

signal state_requirements_changed(can_interact: bool, reason: String)

@export var enable_debug: bool = true
var module_name: String = "StateAwareComponent"

@export_group("State Requirements")
@export var requires_power: bool = false
@export var requires_no_lockdown: bool = false
@export var requires_emergency_mode: bool = false
@export var custom_state_requirements: Dictionary = {}  # e.g. {"player_has_keycard": true}

@export_group("Interaction Messages")
@export var interaction_text_normal: String = "Interact"
@export var interaction_text_no_power: String = "No Power"
@export var interaction_text_lockdown: String = "Lockdown Active"
@export var interaction_text_emergency_only: String = "Emergency Mode Required"
@export var interaction_text_custom: Dictionary = {}  # e.g. {"player_has_keycard": "Keycard Required"}

var parent_node: Node
var interaction_component: InteractionComponent
var current_can_interact: bool = true
var current_reason: String = ""

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	parent_node = get_parent()
	
	# Find interaction component on parent
	for child in parent_node.get_children():
		if child is InteractionComponent:
			interaction_component = child
			break
	
	if not interaction_component:
		DebugLogger.warning(module_name, "No InteractionComponent found on parent")
	
	# Connect to state manager
	if GameManager and GameManager.state_manager:
		GameManager.state_manager.state_changed.connect(_on_state_changed)
	
	# Initial state check
	_check_state_requirements()
	
	DebugLogger.debug(module_name, "StateAwareComponent initialized on " + parent_node.name)

func _on_state_changed(state_name: String, _new_value: Variant) -> void:
	# Check if this state change affects us
	var affects_us = false
	
	if requires_power and state_name == "power":
		affects_us = true
	elif requires_no_lockdown and state_name == "lockdown":
		affects_us = true
	elif requires_emergency_mode and state_name == "emergency_mode":
		affects_us = true
	elif custom_state_requirements.has(state_name):
		affects_us = true
	
	if affects_us:
		_check_state_requirements()

func _check_state_requirements() -> void:
	var can_interact = true
	var reason = interaction_text_normal
	
	if not GameManager or not GameManager.state_manager:
		DebugLogger.warning(module_name, "No GameManager or StateManager found")
		return
	
	var state_manager = GameManager.state_manager
	
	# Check power requirement
	if requires_power and not state_manager.is_power_on():
		can_interact = false
		reason = interaction_text_no_power
	
	# Check lockdown requirement
	elif requires_no_lockdown and state_manager.is_lockdown():
		can_interact = false
		reason = interaction_text_lockdown
	
	# Check emergency mode requirement
	elif requires_emergency_mode and not state_manager.is_emergency_mode():
		can_interact = false
		reason = interaction_text_emergency_only
	
	# Check custom requirements
	else:
		for state_name in custom_state_requirements:
			var required_value = custom_state_requirements[state_name]
			var current_value = state_manager.get_state(state_name)
			
			if current_value != required_value:
				can_interact = false
				if interaction_text_custom.has(state_name):
					reason = interaction_text_custom[state_name]
				else:
					reason = "Requirement not met: " + state_name
				break
	
	# Update interaction component if we have one
	if interaction_component:
		interaction_component.is_disabled = not can_interact
		interaction_component.interaction_text = reason
	
	# Notify parent if state changed
	if can_interact != current_can_interact or reason != current_reason:
		current_can_interact = can_interact
		current_reason = reason
		
		state_requirements_changed.emit(can_interact, reason)
		
		# Call parent method if it exists
		if parent_node.has_method("_on_state_requirements_changed"):
			parent_node._on_state_requirements_changed(can_interact, reason)
		
		DebugLogger.debug(module_name, "State requirements changed - Can interact: " + str(can_interact) + ", Reason: " + reason)

# Public method to check if requirements are met
func can_interact() -> bool:
	return current_can_interact

# Public method to get current interaction text
func get_interaction_text() -> String:
	return current_reason
