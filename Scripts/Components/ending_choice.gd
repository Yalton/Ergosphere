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

var parent_node: Node
var interaction_component: InteractionComponent

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
	
	# Set up interaction
	interaction_component.interaction_text = choice_text
	interaction_component.is_disabled = false
	
	# Connect to interaction
	if not interaction_component.interacted.is_connected(_on_interacted):
		interaction_component.interacted.connect(_on_interacted)
	
	DebugLogger.debug(module_name, "EndingChoiceComponent initialized for path: " + ending_path_id)

func _on_interacted() -> void:
	DebugLogger.info(module_name, "Player selected ending: " + ending_path_id)
	
	# Choose the ending through TaskManager
	if GameManager.task_manager.choose_ending(ending_path_id):
		ending_selected.emit(ending_path_id)
		
		# Disable further interaction
		if interaction_component:
			interaction_component.is_disabled = true
			interaction_component.interaction_text = "Path chosen..."
