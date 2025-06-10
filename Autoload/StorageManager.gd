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
	
	DebugLogger.info(module_name, "StorageManager initialized with " + str(storage_walls.size()) + " storage walls")

func _find_storage_walls() -> void:
	var walls = get_tree().get_nodes_in_group("storage_walls")
	for wall in walls:
		if wall is StorageWall:
			storage_walls.append(wall)
			DebugLogger.debug(module_name, "Found storage wall: " + wall.name)

func _process(delta: float) -> void:
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
func get_occupied_containers() -> Array[String]:
	return occupied_containers.keys()
