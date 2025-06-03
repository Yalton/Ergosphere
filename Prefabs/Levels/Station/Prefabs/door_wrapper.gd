# DoorLockComponent.gd
extends Node3D
class_name DoorWrapper

@export var enable_debug: bool = true
var module_name: String = "DoorWrapper"

## Unique identifier for this door
@export var door_id: String = ""

@export var door: Door

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Add to groups
	add_to_group("door_wrappers")
	
	if door_id != "":
		add_to_group("door_" + door_id)
		DebugLogger.debug(module_name, "Door registered with ID: " + door_id)

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
