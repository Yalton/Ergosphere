# ShopItemRegistry.gd
extends Node
class_name ShopItemRegistry

signal registry_updated

@export var enable_debug: bool = true
var module_name: String = "ShopItemRegistry"

## All registered shop items
@export var registered_items: Array[ShopItem] = []

## Automatically load items from directory on ready
@export var auto_load_from_directory: bool = true

## Directory path to scan for .tres ShopItem resources
@export var items_directory: String = "res://Resources/ShopItems/"

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	if auto_load_from_directory:
		load_items_from_directory()
	
	DebugLogger.info(module_name, "Shop Item Registry initialized with " + str(registered_items.size()) + " items")

## Load all ShopItem resources from the specified directory
func load_items_from_directory() -> void:
	if not DirAccess.dir_exists_absolute(items_directory):
		DebugLogger.warning(module_name, "Items directory does not exist: " + items_directory)
		return
	
	var dir = DirAccess.open(items_directory)
	if not dir:
		DebugLogger.error(module_name, "Failed to open items directory: " + items_directory)
		return
	
	registered_items.clear()
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource_path = items_directory + "/" + file_name
			var resource = load(resource_path)
			
			if resource is ShopItem:
				registered_items.append(resource)
				DebugLogger.debug(module_name, "Loaded shop item: " + resource.display_name + " from " + file_name)
			else:
				DebugLogger.warning(module_name, "File is not a ShopItem resource: " + file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Sort items by category and then by name for consistent ordering
	registered_items.sort_custom(_sort_items)
	
	registry_updated.emit()
	DebugLogger.info(module_name, "Loaded " + str(registered_items.size()) + " items from directory")

## Custom sort function for items
func _sort_items(a: ShopItem, b: ShopItem) -> bool:
	if a.category != b.category:
		return a.category < b.category
	return a.display_name < b.display_name

## Register a single item
func register_item(item: ShopItem) -> void:
	if not item:
		DebugLogger.error(module_name, "Cannot register null item")
		return
	
	# Check if already registered
	for existing in registered_items:
		if existing.item_id == item.item_id:
			DebugLogger.warning(module_name, "Item already registered: " + item.item_id)
			return
	
	registered_items.append(item)
	registry_updated.emit()
	DebugLogger.debug(module_name, "Registered item: " + item.display_name)

## Unregister an item
func unregister_item(item_id: String) -> void:
	for i in range(registered_items.size() - 1, -1, -1):
		if registered_items[i].item_id == item_id:
			var removed = registered_items[i]
			registered_items.remove_at(i)
			registry_updated.emit()
			DebugLogger.debug(module_name, "Unregistered item: " + removed.display_name)
			return
	
	DebugLogger.warning(module_name, "Item not found for unregister: " + item_id)

## Get all items
func get_all_items() -> Array[ShopItem]:
	return registered_items

## Get items by category
func get_items_by_category(category: String) -> Array[ShopItem]:
	var items: Array[ShopItem] = []
	for item in registered_items:
		if item.category == category:
			items.append(item)
	return items

## Get item by ID
func get_item_by_id(item_id: String) -> ShopItem:
	for item in registered_items:
		if item.item_id == item_id:
			return item
	return null

## Get all unique categories
func get_all_categories() -> Array[String]:
	var categories: Array[String] = []
	for item in registered_items:
		if not item.category in categories:
			categories.append(item.category)
	categories.sort()
	return categories

## Validate all items (check scene paths exist)
func validate_items() -> void:
	var invalid_count = 0
	
	for item in registered_items:
		if item.scene_path.is_empty():
			DebugLogger.warning(module_name, "Item has no scene path: " + item.display_name)
			invalid_count += 1
		elif not ResourceLoader.exists(item.scene_path):
			DebugLogger.error(module_name, "Scene path does not exist for item: " + item.display_name + " - " + item.scene_path)
			invalid_count += 1
	
	if invalid_count == 0:
		DebugLogger.info(module_name, "All items validated successfully")
	else:
		DebugLogger.warning(module_name, str(invalid_count) + " items have invalid scene paths")

## Create test items for development
func create_test_items() -> void:
	registered_items.clear()
	
	# General items
	var test_cube = ShopItem.new()
	test_cube.item_id = "test_cube"
	test_cube.display_name = "Test Cube"
	test_cube.description = "A simple test cube for storage testing"
	test_cube.cost = 50
	test_cube.delivery_time = 10.0
	test_cube.category = "General"
	test_cube.scene_path = "res://Prefabs/Test/test_cube.tscn"
	register_item(test_cube)
	
	var energy_cell = ShopItem.new()
	energy_cell.item_id = "energy_cell"
	energy_cell.display_name = "Energy Cell"
	energy_cell.description = "Portable power source for emergency systems"
	energy_cell.cost = 100
	energy_cell.delivery_time = 20.0
	energy_cell.category = "General"
	energy_cell.scene_path = "res://Prefabs/Items/energy_cell.tscn"
	register_item(energy_cell)
	
	var oxygen_tank = ShopItem.new()
	oxygen_tank.item_id = "oxygen_tank"
	oxygen_tank.display_name = "Oxygen Tank"
	oxygen_tank.description = "Emergency oxygen supply"
	oxygen_tank.cost = 125
	oxygen_tank.delivery_time = 25.0
	oxygen_tank.category = "General"
	oxygen_tank.scene_path = "res://Prefabs/Items/oxygen_tank.tscn"
	register_item(oxygen_tank)
	
	var repair_kit = ShopItem.new()
	repair_kit.item_id = "repair_kit"
	repair_kit.display_name = "Repair Kit"
	repair_kit.description = "Basic tools for emergency repairs"
	repair_kit.cost = 150
	repair_kit.delivery_time = 30.0
	repair_kit.category = "General"
	repair_kit.scene_path = "res://Prefabs/Items/repair_kit.tscn"
	register_item(repair_kit)
	
	# Replacement Parts
	var power_module = ShopItem.new()
	power_module.item_id = "power_module"
	power_module.display_name = "Power Module"
	power_module.description = "Replacement power regulation module"
	power_module.cost = 200
	power_module.delivery_time = 45.0
	power_module.category = "Replacement Parts"
	power_module.scene_path = "res://Prefabs/Items/power_module.tscn"
	register_item(power_module)
	
	var cooling_unit = ShopItem.new()
	cooling_unit.item_id = "cooling_unit"
	cooling_unit.display_name = "Cooling Unit"
	cooling_unit.description = "Replacement cooling system component"
	cooling_unit.cost = 250
	cooling_unit.delivery_time = 50.0
	cooling_unit.category = "Replacement Parts"
	cooling_unit.scene_path = "res://Prefabs/Items/cooling_unit.tscn"
	register_item(cooling_unit)
	
	var circuit_board = ShopItem.new()
	circuit_board.item_id = "circuit_board"
	circuit_board.display_name = "Circuit Board"
	circuit_board.description = "Replacement control circuit board"
	circuit_board.cost = 300
	circuit_board.delivery_time = 60.0
	circuit_board.category = "Replacement Parts"
	circuit_board.scene_path = "res://Prefabs/Items/circuit_board.tscn"
	register_item(circuit_board)
	
	DebugLogger.info(module_name, "Created " + str(registered_items.size()) + " test items")
