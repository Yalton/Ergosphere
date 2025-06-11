# StorageManager.gd
extends Node
class_name StorageManager

signal item_ordered(item_id: String, container_location: String)
signal item_delivered(item_id: String, container_location: String)
signal requisition_spent(amount: int)

@export var enable_debug: bool = true
var module_name: String = "StorageManager"

## Current requisition points
@export var current_requisition: int = 0

## References to storage walls
@export var storage_walls: Array[StorageWall] = []

## Available items in the shop catalog
@export var shop_catalog: Array[ShopItem] = []

var delay : int = 10

# Internal tracking
var pending_orders: Array[PendingOrder] = []
var occupied_containers: Dictionary = {} # "A1" -> item_id

class PendingOrder:
	var item_id: String
	var container_location: String
	var delivery_time: float
	
	func _init(id: String, location: String, time: float):
		item_id = id
		container_location = location
		delivery_time = time

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Find storage walls if not assigned
	if storage_walls.is_empty():
		_find_storage_walls()
	
	create_test_items()
	
	DebugLogger.info(module_name, "StorageManager initialized with " + str(storage_walls.size()) + " storage walls")

func _find_storage_walls() -> void:
	var walls = get_tree().get_nodes_in_group("storage_walls")
	for wall in walls:
		if wall is StorageWall:
			storage_walls.append(wall)
			DebugLogger.debug(module_name, "Found storage wall: " + wall.name)

func _process(delta: float) -> void:
	if storage_walls.is_empty():
		delay = delay - 1
		if delay > 0: 
			_find_storage_walls()
		else: 
			delay = 10 
		
	_process_pending_orders(delta)

func _process_pending_orders(delta: float) -> void:
	for i in range(pending_orders.size() - 1, -1, -1):
		var order = pending_orders[i]
		order.delivery_time -= delta
		
		if order.delivery_time <= 0.0:
			_deliver_order(order)
			pending_orders.remove_at(i)

## Add requisition points (called when tasks complete)
func add_requisition(amount: int) -> void:
	current_requisition += amount
	DebugLogger.info(module_name, "Added " + str(amount) + " requisition. Total: " + str(current_requisition))

## Check if player can afford an item
func can_afford_item(item_id: String) -> bool:
	var item = _find_catalog_item(item_id)
	if not item:
		return false
	return current_requisition >= item.cost

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
	
## Order an item from the catalog
func order_item(item_id: String) -> bool:
	var item = _find_catalog_item(item_id)
	if not item:
		DebugLogger.warning(module_name, "Item not found in catalog: " + item_id)
		return false
	
	if not can_afford_item(item_id):
		DebugLogger.warning(module_name, "Insufficient requisition for item: " + item_id)
		return false
	
	var container_location = _find_empty_container()
	if container_location.is_empty():
		DebugLogger.warning(module_name, "No empty containers available")
		return false
	
	# Deduct cost
	current_requisition -= item.cost
	requisition_spent.emit(item.cost)
	
	# Create pending order
	var order = PendingOrder.new(item_id, container_location, item.delivery_time)
	pending_orders.append(order)
	
	# Mark container as occupied
	occupied_containers[container_location] = item_id
	
	DebugLogger.info(module_name, "Ordered " + item_id + " for " + str(item.cost) + " requisition. Delivering to " + container_location)
	item_ordered.emit(item_id, container_location)
	
	return true

## Find an empty storage container
func _find_empty_container() -> String:
	var available_containers: Array[String] = []
	
	# Collect all possible container locations
	for wall in storage_walls:
		var wall_id = wall.wall_id
		for i in range(1, 9): # Containers 1-8
			var location = wall_id + str(i)
			if not occupied_containers.has(location):
				available_containers.append(location)
	
	if available_containers.is_empty():
		return ""
	
	# Pick random empty container
	var random_index = randi() % available_containers.size()
	return available_containers[random_index]

## Deliver an order to its container
func _deliver_order(order: PendingOrder) -> void:
	var wall_id = order.container_location.substr(0, 1) # "A", "B", or "C"
	var container_num = int(order.container_location.substr(1, 1)) # 1-8
	
	# Find the storage wall
	var target_wall: StorageWall = null
	for wall in storage_walls:
		if wall.wall_id == wall_id:
			target_wall = wall
			break
	
	if not target_wall:
		DebugLogger.error(module_name, "Storage wall not found: " + wall_id)
		return
	
	# Find catalog item for scene path
	var item = _find_catalog_item(order.item_id)
	if not item:
		DebugLogger.error(module_name, "Catalog item not found: " + order.item_id)
		return
	
	# Command the wall to load the item
	target_wall.load_item_in_container(container_num, item.scene_path)
	
	DebugLogger.info(module_name, "Delivered " + order.item_id + " to " + order.container_location)
	item_delivered.emit(order.item_id, order.container_location)

## Called when a container is opened and item removed
func container_emptied(wall_id: String, container_num: int) -> void:
	var location = wall_id + str(container_num)
	if occupied_containers.has(location):
		var item_id = occupied_containers[location]
		occupied_containers.erase(location)
		DebugLogger.debug(module_name, "Container " + location + " emptied of " + item_id)

## Called when any storage container is interacted with
func on_container_closed(container: StorageContainer) -> void:
	# Find which wall and container number this is
	for wall in storage_walls:
		for i in range(wall.containers.size()):
			if wall.containers[i] == container:
				var location = wall.wall_id + str(i + 1)
				# If container is empty and was occupied, mark as emptied
				if container.is_empty() and occupied_containers.has(location):
					container_emptied(wall.wall_id, i + 1)
					DebugLogger.debug(module_name, "Container closed and emptied: " + location)
				return

## Get current requisition amount
func get_requisition() -> int:
	return current_requisition

## Get available catalog items
func get_catalog() -> Array[ShopItem]:
	return shop_catalog

## Find item in catalog
func _find_catalog_item(item_id: String) -> ShopItem:
	for item in shop_catalog:
		if item.item_id == item_id:
			return item
	return null

## Get number of pending orders
func get_pending_order_count() -> int:
	return pending_orders.size()

## Get list of occupied container locations
func get_occupied_containers() -> Array:
	return occupied_containers.keys()


func create_test_items() -> void:
	shop_catalog.clear()
	
	# General items
	var test_cube = ShopItem.new()
	test_cube.item_id = "test_cube"
	test_cube.display_name = "Test Cube"
	test_cube.description = "A simple test cube for storage testing"
	test_cube.cost = 50
	test_cube.delivery_time = 1.0
	test_cube.category = "General"
	test_cube.scene_path = "res://Prefabs/Props/Industrial/lubricant_spray.tscn"
	register_item(test_cube)
	
	var energy_cell = ShopItem.new()
	energy_cell.item_id = "energy_cell"
	energy_cell.display_name = "Energy Cell"
	energy_cell.description = "Portable power source for emergency systems"
	energy_cell.cost = 100
	energy_cell.delivery_time = 20.0
	energy_cell.category = "General"
	energy_cell.scene_path = "res://Prefabs/Props/Industrial/lubricant_spray.tscn"
	register_item(energy_cell)
	
	var oxygen_tank = ShopItem.new()
	oxygen_tank.item_id = "oxygen_tank"
	oxygen_tank.display_name = "Oxygen Tank"
	oxygen_tank.description = "Emergency oxygen supply"
	oxygen_tank.cost = 125
	oxygen_tank.delivery_time = 25.0
	oxygen_tank.category = "General"
	oxygen_tank.scene_path = "res://Prefabs/Props/Industrial/lubricant_spray.tscn"
	register_item(oxygen_tank)
	
	var repair_kit = ShopItem.new()
	repair_kit.item_id = "repair_kit"
	repair_kit.display_name = "Repair Kit"
	repair_kit.description = "Basic tools for emergency repairs"
	repair_kit.cost = 150
	repair_kit.delivery_time = 30.0
	repair_kit.category = "General"
	repair_kit.scene_path = "res://Prefabs/Props/Industrial/lubricant_spray.tscn"
	register_item(repair_kit)
	
	# Replacement Parts
	var power_module = ShopItem.new()
	power_module.item_id = "power_module"
	power_module.display_name = "Power Module"
	power_module.description = "Replacement power regulation module"
	power_module.cost = 200
	power_module.delivery_time = 45.0
	power_module.category = "Replacement Parts"
	power_module.scene_path = "res://Prefabs/Props/Industrial/lubricant_spray.tscn"
	register_item(power_module)
	
	var cooling_unit = ShopItem.new()
	cooling_unit.item_id = "cooling_unit"
	cooling_unit.display_name = "Cooling Unit"
	cooling_unit.description = "Replacement cooling system component"
	cooling_unit.cost = 250
	cooling_unit.delivery_time = 50.0
	cooling_unit.category = "Replacement Parts"
	cooling_unit.scene_path = "res://Prefabs/Props/Industrial/lubricant_spray.tscn"
	register_item(cooling_unit)
	
	var circuit_board = ShopItem.new()
	circuit_board.item_id = "circuit_board"
	circuit_board.display_name = "Circuit Board"
	circuit_board.description = "Replacement control circuit board"
	circuit_board.cost = 300
	circuit_board.delivery_time = 60.0
	circuit_board.category = "Replacement Parts"
	circuit_board.scene_path = "res://Prefabs/Props/Industrial/lubricant_spray.tscn"
	register_item(circuit_board)
	
	DebugLogger.info(module_name, "Created " + str(shop_catalog.size()) + " test items")
