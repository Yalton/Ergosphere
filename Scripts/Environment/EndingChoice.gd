# EndingChoiceComponent.gd
extends Node
class_name EndingChoiceComponent

signal ending_selected(path_id: String)

@export var enable_debug: bool = true
var module_name: String = "EndingChoiceComponent"

@export_group("Ending Settings")
## The ending path this component represents (ending_a or ending_b)
@export var ending_path_id: String = "ending_a"
## Text shown when hovering over this ending choice
@export var choice_text: String = "Choose this path..."
## Only show during these game states
@export var show_during_states: Dictionary = {"reality_collapse": true}

var parent_node: Node
var interaction_component: InteractionComponent
var is_available: bool = false

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	parent_node = get_parent()
	
	# Find interaction component
	for child in parent_node.get_children():
		if child is InteractionComponent:
			interaction_component = child
			break
	
	if not interaction_component:
		DebugLogger.error(module_name, "No InteractionComponent found on parent")
		return
	
	# Connect to interaction
	if not interaction_component.interacted.is_connected(_on_interacted):
		interaction_component.interacted.connect(_on_interacted)
	
	# Connect to ending path signals
	if GameManager.task_manager:
		GameManager.task_manager.ending_path_available.connect(_on_ending_path_available)
		GameManager.state_manager.state_changed.connect(_on_state_changed)
	
	# Initial visibility check
	_update_visibility()
	
	DebugLogger.debug(module_name, "EndingChoiceComponent initialized for path: " + ending_path_id)

func _on_ending_path_available(path_id: String) -> void:
	if path_id == ending_path_id:
		DebugLogger.info(module_name, "Our ending path is now available: " + path_id)
		_update_visibility()

func _on_state_changed(key: String, value) -> void:
	# Check if we should show/hide based on state changes
	if key in show_during_states:
		_update_visibility()

func _update_visibility() -> void:
	if not GameManager.task_manager:
		return
	
	# Check if our ending path is available
	var path_available = GameManager.task_manager.is_ending_path_available(ending_path_id)
	
	# Check if we're in the right state to show
	var correct_state = true
	for state_key in show_during_states:
		var required_value = show_during_states[state_key]
		if GameManager.state_manager.get_state(state_key) != required_value:
			correct_state = false
			break
	
	# Check if an ending has already been chosen
	var ending_already_chosen = GameManager.task_manager.chosen_ending != ""
	
	# Update availability
	is_available = path_available and correct_state and not ending_already_chosen
	
	# Update interaction component
	if interaction_component:
		interaction_component.is_disabled = not is_available
		if is_available:
			interaction_component.interaction_text = choice_text
		else:
			interaction_component.interaction_text = ""
	
	# Update parent visibility
	if parent_node:
		parent_node.visible = is_available
	
	DebugLogger.debug(module_name, "Visibility updated - Available: %s, Path ready: %s, Correct state: %s" % [is_available, path_available, correct_state])

func _on_interacted() -> void:
	if not is_available:
		return
	
	DebugLogger.info(module_name, "Player selected ending: " + ending_path_id)
	
	# Choose the ending through TaskManager
	if GameManager.task_manager.choose_ending(ending_path_id):
		ending_selected.emit(ending_path_id)
		
		# Hide all ending choices
		_update_visibility()
		
		# You might want to trigger specific ending sequences here
		# For example, changing to a specific state or scene
		GameManager.state_manager.set_state("ending_triggered", true)
		GameManager.state_manager.set_state("ending_type", ending_path_id)
