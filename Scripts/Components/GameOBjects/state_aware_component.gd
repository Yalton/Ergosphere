# state_aware_component.gd - FIXED with CommonUtils state checking
extends Node
class_name StateAwareComponent

signal state_requirements_changed(can_interact: bool, reason: String)

## Enable debug logging for this component
@export var enable_debug: bool = true
var module_name: String = "StateAwareComponent"

@export_group("State Requirements")
## Component requires power to be on to function
@export var requires_power: bool = false
## Component requires no lockdown to be active
@export var requires_no_lockdown: bool = false
## Component requires emergency mode to be active
@export var requires_emergency_mode: bool = false
## Custom state requirements as key-value pairs
@export var custom_state_requirements: Dictionary = {}  # e.g. {"player_has_keycard": true}

@export_group("Interaction Messages")
## Message shown when all requirements are met
@export var interaction_text_normal: String = "Interact"
## Message shown when power is required but off
@export var interaction_text_no_power: String = "No Power"
## Message shown when lockdown is active
@export var interaction_text_lockdown: String = "Lockdown Active"
## Message shown when emergency mode is required but not active
@export var interaction_text_emergency_only: String = "Emergency Mode Required"
## Custom messages for custom state requirements
@export var interaction_text_custom: Dictionary = {}  # e.g. {"player_has_keycard": "Keycard Required"}

var parent_node: Node
var interaction_component: InteractionComponent
var current_can_interact: bool = true
var current_reason: String = ""

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	parent_node = get_parent()
	
	# Find interaction component on parent
	interaction_component = CommonUtils.find_child_of_type(parent_node, "InteractionComponent")
	
	if not interaction_component:
		DebugLogger.warning(module_name, "No InteractionComponent found on parent")
	
	# Connect to state manager using CommonUtils
	if GameManager and GameManager.state_manager:
		CommonUtils.connect_signal_safe(GameManager.state_manager, "state_changed", self, "_on_state_changed")
	
	# Initial state check
	_check_state_requirements()
	
	DebugLogger.debug(module_name, "StateAwareComponent initialized on " + parent_node.name)

func _on_state_changed(state_name: String, _new_value: Variant) -> void:
	# Check if this state change affects us
	var affects_us = false
	
	if requires_power and state_name == CommonUtils.STATE_POWER:
		affects_us = true
	elif requires_no_lockdown and state_name == CommonUtils.STATE_LOCKDOWN:
		affects_us = true
	elif requires_emergency_mode and state_name == CommonUtils.STATE_EMERGENCY_MODE:
		affects_us = true
	elif custom_state_requirements.has(state_name):
		affects_us = true
	
	if affects_us:
		_check_state_requirements()

func _check_state_requirements() -> void:
	var can_interact_local = true
	var reason = interaction_text_normal
	
	if not GameManager or not GameManager.state_manager:
		DebugLogger.warning(module_name, "No GameManager or StateManager found")
		return
	
	# Check power requirement using CommonUtils
	if requires_power and not CommonUtils.is_power_on():
		can_interact_local = false
		reason = interaction_text_no_power
	
	# Check lockdown requirement using CommonUtils
	elif requires_no_lockdown and CommonUtils.is_lockdown():
		can_interact_local = false
		reason = interaction_text_lockdown
	
	# Check emergency mode requirement using CommonUtils
	elif requires_emergency_mode and not CommonUtils.is_emergency_mode():
		can_interact_local = false
		reason = interaction_text_emergency_only
	
	# Check custom requirements using CommonUtils
	else:
		for state_name in custom_state_requirements:
			var required_value = custom_state_requirements[state_name]
			var current_value = CommonUtils.check_game_state(state_name, required_value)
			
			if not current_value:
				can_interact_local = false
				if interaction_text_custom.has(state_name):
					reason = interaction_text_custom[state_name]
				else:
					reason = "Requirement not met: " + state_name
				break
	
	# Update interaction component if we have one
	if interaction_component:
		interaction_component.is_disabled = not can_interact_local
		interaction_component.interaction_text = reason
	
	# Notify parent if state changed
	if can_interact_local != current_can_interact or reason != current_reason:
		current_can_interact = can_interact_local
		current_reason = reason
		
		state_requirements_changed.emit(can_interact_local, reason)
		
		# Call parent method if it exists using CommonUtils
		CommonUtils.safe_call(parent_node, "_on_state_requirements_changed", [can_interact_local, reason])
		
		DebugLogger.debug(module_name, "State requirements changed - Can interact: " + str(can_interact_local) + ", Reason: " + reason)

# Public method to check if requirements are met
func can_interact() -> bool:
	return current_can_interact

# Public method to get current interaction text
func get_interaction_text() -> String:
	return current_reason
