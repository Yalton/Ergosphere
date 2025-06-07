# StorageContainerLabel.gd
extends Node3D
class_name StorageContainerLabel

@export var enable_debug: bool = true
var module_name: String = "StorageContainerLabel"

## Text to display on the storage container label
@export var container_label_text: String = "Storage"

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Update the container label
	_update_container_label()
	
	DebugLogger.debug(module_name, "Storage container label initialized")

func _update_container_label() -> void:
	if container_label_text != "":
		var label = _find_label()
		if label:
			label.text = container_label_text
			DebugLogger.debug(module_name, "Set container label to: " + container_label_text)
		else:
			DebugLogger.warning(module_name, "Could not find label in storage container")

func _find_label() -> Label:
	# Look for Control -> PanelContainer -> Label structure
	var control = find_child("Control", true, false)
	if not control:
		DebugLogger.warning(module_name, "Could not find Control node")
		return null
	
	var panel_container = control.find_child("PanelContainer", true, false)
	if not panel_container:
		DebugLogger.warning(module_name, "Could not find PanelContainer under Control")
		return null
	
	var label = panel_container.find_child("Label", true, false)
	if not label:
		DebugLogger.warning(module_name, "Could not find Label under PanelContainer")
		return null
	
	return label

# Public method to update label at runtime if needed
func set_label_text(text: String) -> void:
	container_label_text = text
	var label = _find_label()
	if label:
		label.text = text
		DebugLogger.debug(module_name, "Updated label to: " + text)
