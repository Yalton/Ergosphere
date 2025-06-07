# DoorWrapper.gd (or add to your existing station door script)
extends Node3D
class_name DoorWrapper

@export var enable_debug: bool = true
var module_name: String = "DoorWrapper"

## Unique identifier for this door
@export var door_id: String = ""
@export var door: Door

## Text to display on the entrance side sign
@export var entrance_label_text: String = ""
## Text to display on the exit side sign  
@export var exit_label_text: String = ""

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Add to groups
	add_to_group("door_wrappers")
	if door_id != "":
		add_to_group("door_" + door_id)
	
	# Update the door signs
	_update_door_signs()
	
	DebugLogger.debug(module_name, "Door registered with ID: " + door_id)

func _update_door_signs() -> void:
	# Find and update entrance label
	if entrance_label_text != "":
		var entrance_label = _find_label_in_viewport("Entrance")
		if entrance_label:
			entrance_label.text = entrance_label_text
			DebugLogger.debug(module_name, "Set entrance label to: " + entrance_label_text)
		else:
			DebugLogger.warning(module_name, "Could not find entrance label")
	
	# Find and update exit label
	if exit_label_text != "":
		var exit_label = _find_label_in_viewport("Exit")
		if exit_label:
			exit_label.text = exit_label_text
			DebugLogger.debug(module_name, "Set exit label to: " + exit_label_text)
		else:
			DebugLogger.warning(module_name, "Could not find exit label")

func _find_label_in_viewport(viewport_name: String) -> Label:
	# Look for the viewport node by name
	var viewport_node = find_child(viewport_name, true, false)
	if not viewport_node:
		DebugLogger.warning(module_name, "Could not find viewport: " + viewport_name)
		return null
	
	# Look for Control -> PanelContainer -> Label structure
	var control = viewport_node.find_child("Control", true, false)
	if not control:
		DebugLogger.warning(module_name, "Could not find Control under: " + viewport_name)
		return null
	
	var panel_container = control.find_child("PanelContainer", true, false)
	if not panel_container:
		DebugLogger.warning(module_name, "Could not find PanelContainer under Control in: " + viewport_name)
		return null
	
	var label = panel_container.find_child("Label", true, false)
	if not label:
		DebugLogger.warning(module_name, "Could not find Label under PanelContainer in: " + viewport_name)
		return null
	
	return label

# Lock this door
func lock_door() -> void:
	if door:
		door.lock()
		DebugLogger.info(module_name, "Door locked: " + door_id)

# Unlock this door
func unlock_door() -> void:
	if door:
		door.unlock()
		DebugLogger.info(module_name, "Door unlocked: " + door_id)

# Check if locked
func is_locked() -> bool:
	return door.is_locked if door else false

# Public method to update labels at runtime if needed
func set_entrance_label(text: String) -> void:
	entrance_label_text = text
	var entrance_label = _find_label_in_viewport("Entrance")
	if entrance_label:
		entrance_label.text = text

func set_exit_label(text: String) -> void:
	exit_label_text = text
	var exit_label = _find_label_in_viewport("Exit")
	if exit_label:
		exit_label.text = text
