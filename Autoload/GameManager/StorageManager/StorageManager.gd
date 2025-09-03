# StorageManager.gd
extends Node
class_name StorageManager

signal item_ordered(item_id: String, container_location: String)
signal item_delivered(item_id: String, container_location: String)
signal requisition_spent(amount: int)

@export var enable_debug: bool = true
var module_name: String = "StorageManager"

## Current requisition points - keeping variable but not using it
@export var current_requisition: int = 5000

## Available items in the shop catalog
@export var shop_catalog: Array[ShopItem] = []

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Clear any persisted state when ready
	reset_state()
	
	_register_exported_items()
	
	# Only create test items if no exported items exist
	if shop_catalog.is_empty():
		create_test_items()
		
	DebugLogger.info(module_name, "StorageManager initialized")

## Reset all state - call this when starting a new game
func reset_state() -> void:
	current_requisition = 5000
	DebugLogger.info(module_name, "State reset for new game")

func _register_exported_items() -> void:
	if shop_catalog.is_empty():
		DebugLogger.debug(module_name, "No exported items to register")
		return
	
	var registered_count = 0
	var duplicate_count = 0
	
	# Create a temporary array to avoid modifying while iterating
	var items_to_register = shop_catalog.duplicate()
	shop_catalog.clear()
	
	for item in items_to_register:
		if not item:
			DebugLogger.warning(module_name, "Skipping null item in export array")
			continue
			
		if item.item_id.is_empty():
			DebugLogger.warning(module_name, "Skipping item with empty ID: " + item.display_name)
			continue
		
		# Check for duplicates
		var dup = false
		for existing in shop_catalog:
			if existing.item_id == item.item_id:
				DebugLogger.warning(module_name, "Duplicate item ID found: " + item.item_id)
				dup = true
				duplicate_count += 1
				break
		
		if not dup:
			shop_catalog.append(item)
			registered_count += 1
			DebugLogger.debug(module_name, "Registered exported item: " + item.display_name + " (ID: " + item.item_id + ")")
	
	DebugLogger.info(module_name, "Registered " + str(registered_count) + " exported items (" + str(duplicate_count) + " duplicates skipped)")

## Add requisition points (called when tasks complete) - keeping for compatibility
func add_requisition(amount: int) -> void:
	current_requisition += amount
	DebugLogger.info(module_name, "Added " + str(amount) + " requisition. Total: " + str(current_requisition))

## Check if player can afford an item - ALWAYS RETURNS TRUE NOW
func can_afford_item(item_id: String) -> bool:
	var item = get_item_by_id(item_id)
	if not item:
		return false
	# Items are free now!
	return true

## Register a single item
func register_item(item: ShopItem) -> void:
	if not item:
		DebugLogger.error(module_name, "Cannot register null item")
		return
	
	# Check if already registered
	for existing in shop_catalog:
		if existing.item_id == item.item_id:
			DebugLogger.warning(module_name, "Item already registered: " + item.item_id)
			return
	
	shop_catalog.append(item)
	DebugLogger.debug(module_name, "Registered item: " + item.display_name)

## Unregister an item
func unregister_item(item_id: String) -> void:
	for i in range(shop_catalog.size() - 1, -1, -1):
		if shop_catalog[i].item_id == item_id:
			var removed = shop_catalog[i]
			shop_catalog.remove_at(i)
			DebugLogger.debug(module_name, "Unregistered item: " + removed.display_name)
			return
	
	DebugLogger.warning(module_name, "Item not found for unregister: " + item_id)

## Get all items
func get_all_items() -> Array[ShopItem]:
	return shop_catalog

## Get items by category
func get_items_by_category(category: String) -> Array[ShopItem]:
	var items: Array[ShopItem] = []
	for item in shop_catalog:
		if item.category == category:
			items.append(item)
	return items

## Get item by ID
func get_item_by_id(item_id: String) -> ShopItem:
	for item in shop_catalog:
		if item.item_id == item_id:
			return item
	return null

## Get all unique categories
func get_all_categories() -> Array[String]:
	var categories: Array[String] = []
	for item in shop_catalog:
		if not item.category in categories:
			categories.append(item.category)
	categories.sort()
	return categories

## Order an item from the catalog - NO COST CHECK OR DEDUCTION
func order_item(item_id: String) -> bool:
	var item = get_item_by_id(item_id)
	if not item:
		DebugLogger.warning(module_name, "Item not found in catalog: " + item_id)
		return false
	
	# No cost check needed - items are free!
	
	# Find a wall with empty containers
	var target = _find_empty_container()
	if not target.wall:
		DebugLogger.warning(module_name, "No empty containers available in any storage wall")
		return false
	
	# No cost deduction - items are free!
	
	# Deliver immediately
	var location = target.wall.wall_id + str(target.container_num)
	if target.wall.load_item_in_container(target.container_num, item.scene_path):
		DebugLogger.info(module_name, "Delivered " + item_id + " to " + location + " (FREE)")
		item_ordered.emit(item_id, location)
		item_delivered.emit(item_id, location)
		return true
	else:
		DebugLogger.error(module_name, "Failed to deliver item to container")
		return false

## Find an empty storage container by querying walls dynamically
func _find_empty_container() -> Dictionary:
	# Get all storage walls from the scene
	var walls = get_tree().get_nodes_in_group("storage_walls")
	
	if walls.is_empty():
		DebugLogger.warning(module_name, "No storage walls found in scene")
		return {"wall": null, "container_num": 0}
	
	# Filter to walls that have empty containers
	var walls_with_space: Array = []
	for wall in walls:
		if wall is StorageWall:
			var empty_count = wall.get_empty_container_count()
			if empty_count > 0:
				walls_with_space.append(wall)
				DebugLogger.debug(module_name, "Wall " + wall.wall_id + " has " + str(empty_count) + " empty containers")
	
	if walls_with_space.is_empty():
		DebugLogger.debug(module_name, "No walls have empty containers")
		return {"wall": null, "container_num": 0}
	
	# Pick a random wall from those with space
	var chosen_wall = walls_with_space[randi() % walls_with_space.size()]
	
	# Get empty container numbers from chosen wall
	var empty_containers = chosen_wall.get_empty_container_numbers()
	if empty_containers.is_empty():
		DebugLogger.error(module_name, "Wall reported space but has no empty containers")
		return {"wall": null, "container_num": 0}
	
	# Pick a random empty container
	var chosen_container = empty_containers[randi() % empty_containers.size()]
	
	DebugLogger.debug(module_name, "Selected container " + chosen_wall.wall_id + str(chosen_container))
	return {"wall": chosen_wall, "container_num": chosen_container}

## Get count of total available containers across all walls
func get_available_container_count() -> int:
	var total_available = 0
	var walls = get_tree().get_nodes_in_group("storage_walls")
	
	for wall in walls:
		if wall is StorageWall:
			total_available += wall.get_empty_container_count()
	
	return total_available

## Check if any containers are available
func has_available_containers() -> bool:
	return get_available_container_count() > 0

## Get current requisition amount
func get_requisition() -> int:
	return current_requisition

## Get available catalog items
func get_catalog() -> Array[ShopItem]:
	return shop_catalog

func create_test_items() -> void:
	shop_catalog.clear()
	
	# General items
	var test_cube = ShopItem.new()
	test_cube.item_id = "test_cube"
	test_cube.display_name = "Test Cube"
	test_cube.description = "A simple test cube for storage testing"
	test_cube.cost = 0  # FREE
	test_cube.delivery_time = 1.0
	test_cube.category = "General"
	test_cube.scene_path = "res://Prefabs/Environment/Props/Industrial/lubricant_spray.tscn"
	register_item(test_cube)
	
	var energy_cell = ShopItem.new()
	energy_cell.item_id = "energy_cell"
	energy_cell.display_name = "Energy Cell"
	energy_cell.description = "Portable power source for emergency systems"
	energy_cell.cost = 0  # FREE
	energy_cell.delivery_time = 20.0
	energy_cell.category = "General"
	energy_cell.scene_path = "res://Prefabs/Environment/Props/Industrial/lubricant_spray.tscn"
	register_item(energy_cell)
	
	var oxygen_tank = ShopItem.new()
	oxygen_tank.item_id = "oxygen_tank"
	oxygen_tank.display_name = "Oxygen Tank"
	oxygen_tank.description = "Emergency oxygen supply"
	oxygen_tank.cost = 0  # FREE
	oxygen_tank.delivery_time = 25.0
	oxygen_tank.category = "General"
	oxygen_tank.scene_path = "res://Prefabs/Environment/Props/Industrial/lubricant_spray.tscn"
	register_item(oxygen_tank)
	
	var repair_kit = ShopItem.new()
	repair_kit.item_id = "repair_kit"
	repair_kit.display_name = "Repair Kit"
	repair_kit.description = "Basic tools for emergency repairs"
	repair_kit.cost = 0  # FREE
	repair_kit.delivery_time = 30.0
	repair_kit.category = "General"
	repair_kit.scene_path = "res://Prefabs/Environment/Props/Industrial/lubricant_spray.tscn"
	register_item(repair_kit)
	
	# Replacement Parts
	var power_module = ShopItem.new()
	power_module.item_id = "power_module"
	power_module.display_name = "Power Module"
	power_module.description = "Replacement power regulation module"
	power_module.cost = 0  # FREE
	power_module.delivery_time = 45.0
	power_module.category = "Replacement Parts"
	power_module.scene_path = "res://Prefabs/Environment/Props/Industrial/lubricant_spray.tscn"
	register_item(power_module)
	
	var cooling_unit = ShopItem.new()
	cooling_unit.item_id = "cooling_unit"
	cooling_unit.display_name = "Cooling Unit"
	cooling_unit.description = "Replacement cooling system component"
	cooling_unit.cost = 0  # FREE
	cooling_unit.delivery_time = 50.0
	cooling_unit.category = "Replacement Parts"
	cooling_unit.scene_path = "res://Prefabs/Environment/Props/Industrial/lubricant_spray.tscn"
	register_item(cooling_unit)
	
	var circuit_board = ShopItem.new()
	circuit_board.item_id = "circuit_board"
	circuit_board.display_name = "Circuit Board"
	circuit_board.description = "Replacement control circuit board"
	circuit_board.cost = 0  # FREE
	circuit_board.delivery_time = 60.0
	circuit_board.category = "Replacement Parts"
	circuit_board.scene_path = "res://Prefabs/Environment/Props/Industrial/lubricant_spray.tscn"
	register_item(circuit_board)
	
	DebugLogger.info(module_name, "Created " + str(shop_catalog.size()) + " test items (ALL FREE)")
