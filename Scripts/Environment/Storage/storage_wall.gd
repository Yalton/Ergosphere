# StorageWall.gd
extends Node3D
class_name StorageWall

@export var enable_debug: bool = true
var module_name: String = "StorageWall"

## Wall identifier (A, B, or C)
@export var wall_id: String = "A"

## Storage containers (should be 8 containers numbered 1-8)
@export var containers: Array[StorageContainer] = []

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Find containers if not assigned
	if containers.is_empty():
		_find_containers()
	
	# Connect container signals
	_connect_container_signals()
	
	# Add to storage walls group
	add_to_group("storage_walls")
	
	DebugLogger.info(module_name, "StorageWall " + wall_id + " initialized with " + str(containers.size()) + " containers")

func _find_containers() -> void:
	# Look for StorageContainer children
	for child in get_children():
		if child is StorageContainer:
			containers.append(child)
	
	# Sort containers by name to ensure consistent numbering
	containers.sort_custom(func(a, b): return a.name < b.name)

func _connect_container_signals() -> void:
	for container in containers:
		if not container.container_opened.is_connected(_on_container_opened):
			container.container_opened.connect(_on_container_opened)
		if not container.container_closed.is_connected(_on_container_closed):
			container.container_closed.connect(_on_container_closed)

## Load an item into a specific container
func load_item_in_container(container_number: int, scene_path: String) -> bool:
	if container_number < 1 or container_number > containers.size():
		DebugLogger.error(module_name, "Invalid container number: " + str(container_number))
		return false
	
	var container = containers[container_number - 1] # Convert to 0-based index
	if not container:
		DebugLogger.error(module_name, "Container " + str(container_number) + " not found")
		return false
	
	# Only load if container is actually empty
	if not container.is_empty():
		DebugLogger.error(module_name, "Container " + str(container_number) + " is not empty!")
		return false
	
	return container.load_item(scene_path)

## Get specific container
func get_container(container_number: int) -> StorageContainer:
	if container_number < 1 or container_number > containers.size():
		return null
	return containers[container_number - 1]

## Check if container is empty
func is_container_empty(container_number: int) -> bool:
	var container = get_container(container_number)
	if not container:
		return false
	return container.is_empty()

## Get count of empty containers
func get_empty_container_count() -> int:
	var count = 0
	for container in containers:
		if container.is_empty():
			count += 1
	return count

## Get all empty container numbers
func get_empty_container_numbers() -> Array[int]:
	var empty: Array[int] = []
	for i in range(containers.size()):
		if containers[i].is_empty():
			empty.append(i + 1) # Convert back to 1-based
	return empty

func _on_container_opened(container: StorageContainer) -> void:
	var container_num = containers.find(container) + 1
	DebugLogger.debug(module_name, "Container " + wall_id + str(container_num) + " opened")

func _on_container_closed(container: StorageContainer) -> void:
	var container_num = containers.find(container) + 1
	var status = "empty" if container.is_empty() else "full"
	DebugLogger.debug(module_name, "Container " + wall_id + str(container_num) + " closed (" + status + ")")
	
	# Log current wall status
	var empty_count = get_empty_container_count()
	DebugLogger.debug(module_name, "Wall " + wall_id + " now has " + str(empty_count) + " empty containers")
