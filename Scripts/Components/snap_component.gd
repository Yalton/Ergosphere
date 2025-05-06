extends Node
class_name SnapComponent

signal object_snapped(object_name: String, object_node: Node3D)

@export var target_object_name: String = "" # The display_name of the object we're looking for

@onready var area_3d: Area3D = $"../SnapArea"

# Debug properties
@export var enable_debug: bool = true
var module_name: String = "SnapComponent"

func _ready() -> void:
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	
	# Connect area signals
	if area_3d:
		area_3d.body_entered.connect(_on_body_entered)
		area_3d.area_entered.connect(_on_area_entered)
	else:
		DebugLogger.error(module_name, "Area3D node is missing from SnapComponent")
	
	DebugLogger.debug(module_name, "SnapComponent initialized with target: " + target_object_name)

func _on_body_entered(body: Node3D) -> void:
	_check_for_valid_snap(body)

func _on_area_entered(area: Area3D) -> void:
	var parent = area.get_parent()
	_check_for_valid_snap(parent)

func _check_for_valid_snap(object: Node) -> void:
	# Skip if no target name is specified or if it's the wrong object
	if target_object_name.is_empty():
		DebugLogger.debug(module_name, "No target object name specified")
		return
		
	# Check if it's a GameObject with a display_name
	if not (object is GameObject):
		return
		
	var game_object = object as GameObject
	
	# Check if the display_name matches our target
	if game_object.display_name != target_object_name:
		DebugLogger.debug(module_name, "Object name doesn't match: " + game_object.display_name)
		return
	
	# Check if it has a CarryableComponent
	var carriable = game_object.find_child("CarryableComponent", true, false)
	if not carriable:
		DebugLogger.debug(module_name, "Object doesn't have CarryableComponent")
		return
	
	# Check if it's currently being carried
	if not carriable.is_being_carried:
		DebugLogger.debug(module_name, "Object is not being carried")
		return
	
	# If we get here, we have a valid snap!
	DebugLogger.debug(module_name, "Valid snap detected! Object: " + game_object.name)
	
	# Force the object to be dropped
	carriable.leave()
	
	# Emit signal that an object was snapped
	object_snapped.emit(game_object.name, game_object)
	
	# Delete the object - this is still part of the snap component's responsibility
	# since it's directly related to the snap action
	game_object.queue_free()
