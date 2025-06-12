# AwareGameObject.gd
extends GameObject
class_name AwareGameObject

var module_name: String = "AwareGameObject"
signal object_state_updated(interaction_text: String)

# References to awareness components
@export var task_aware_component: TaskAwareComponent
@export var state_aware_component: StateAwareComponent

func _ready() -> void:
	super._ready()
		
	# Auto-find components if not assigned
	if not task_aware_component:
		task_aware_component = get_node_or_null("TaskAwareComponent")
	
	if not state_aware_component:
		state_aware_component = get_node_or_null("StateAwareComponent")
	

# Check if this object can be interacted with
func can_interact() -> bool:
	var interaction_allowed = true
	
	# Check task requirements
	if task_aware_component and not task_aware_component.is_task_available:
		interaction_allowed = false
		DebugLogger.debug(module_name, "Blocked by task requirements")
	
	# Check state requirements
	if state_aware_component and not state_aware_component.can_interact():
		interaction_allowed = false
		DebugLogger.debug(module_name, "Blocked by state requirements")
	
	return interaction_allowed
	
# Get the reason why interaction is blocked
func get_block_reason() -> String:
	if task_aware_component and not task_aware_component.is_task_available:
		return task_aware_component.get_interaction_text()
	
	if state_aware_component and not state_aware_component.can_interact():
		return state_aware_component.get_interaction_text()
	
	return ""
