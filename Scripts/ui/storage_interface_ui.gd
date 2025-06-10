# ShopUIControl.gd
extends Control

signal purchase_attempted(item_id: String)
signal purchase_successful(item_id: String)
signal purchase_failed(item_id: String)

@export var enable_debug: bool = true
var module_name: String = "ShopUIControl"

## UI Elements
@export_group("UI References")
@export var tab_container: TabContainer
@export var general_grid: GridContainer
@export var replacement_parts_grid: GridContainer
@export var requisition_label: Label

## Visual Feedback
@export_group("Visual Settings")
@export var fail_flash_color: Color = Color(1, 0, 0, 0.5)
@export var flash_duration: float = 0.3

## Button Settings
@export_group("Button Settings")
@export var button_min_size: Vector2 = Vector2(360, 160)
@export var button_font_size: int = 14

# Internal references
var storage_manager: StorageManager
var item_buttons: Dictionary = {} # item_id -> Button

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Get storage manager
	if GameManager and GameManager.storage_manager:
		storage_manager = GameManager.storage_manager
		storage_manager.requisition_spent.connect(_on_requisition_spent)
	else:
		DebugLogger.error(module_name, "StorageManager not found!")
	
	# Setup UI
	_setup_ui()
	_populate_shop()
	_update_requisition_display()
	
	DebugLogger.debug(module_name, "Shop UI Control initialized")

func _setup_ui() -> void:
	# Make sure we have the required grids
	if not general_grid:
		DebugLogger.error(module_name, "General grid not assigned!")
	if not replacement_parts_grid:
		DebugLogger.error(module_name, "Replacement parts grid not assigned!")
	
	# Configure grids
	if general_grid:
		general_grid.columns = 3
		general_grid.add_theme_constant_override("h_separation", 10)
		general_grid.add_theme_constant_override("v_separation", 10)
	
	if replacement_parts_grid:
		replacement_parts_grid.columns = 3
		replacement_parts_grid.add_theme_constant_override("h_separation", 10)
		replacement_parts_grid.add_theme_constant_override("v_separation", 10)

func _populate_shop() -> void:
	if not storage_manager:
		return
	
	# Clear existing buttons
	for button in item_buttons.values():
		button.queue_free()
	item_buttons.clear()
	
	# Get items by category
	var general_items = storage_manager.get_items_by_category("General")
	var replacement_items = storage_manager.get_items_by_category("Replacement Parts")
	
	# Populate general grid
	if general_grid:
		for item in general_items:
			_create_item_button(item, general_grid)
	
	# Populate replacement parts grid
	if replacement_parts_grid:
		for item in replacement_items:
			_create_item_button(item, replacement_parts_grid)
	
	DebugLogger.info(module_name, "Populated shop with " + str(general_items.size()) + " general items and " + str(replacement_items.size()) + " replacement parts")

func _create_item_button(item: ShopItem, parent_grid: GridContainer) -> void:
	var button = Button.new()
	button.custom_minimum_size = button_min_size
	button.clip_text = true
	
	# Create button text
	var text = item.display_name + "\n"
	text += str(item.cost) + " REQ"
	
	button.text = text
	button.add_theme_font_size_override("font_size", button_font_size)
	button.pressed.connect(_on_item_button_pressed.bind(item.item_id))
	
	parent_grid.add_child(button)
	item_buttons[item.item_id] = button
	
	# Update button state based on affordability
	_update_button_state(item.item_id)

func _on_item_button_pressed(item_id: String) -> void:
	DebugLogger.debug(module_name, "Purchase attempted for: " + item_id)
	purchase_attempted.emit(item_id)
	
	if not storage_manager:
		_show_purchase_failed(item_id, "No Storage Manager!")
		return
	
	# Attempt purchase
	if storage_manager.order_item(item_id):
		purchase_successful.emit(item_id)
		_update_all_buttons()
		_update_requisition_display()
	else:
		_show_purchase_failed(item_id, "")
		purchase_failed.emit(item_id)

func _show_purchase_failed(item_id: String, reason: String = "") -> void:
	# Flash the button red
	var button = item_buttons.get(item_id, null)
	if button:
		var original_modulate = button.modulate
		var tween = create_tween()
		tween.tween_property(button, "modulate", fail_flash_color, flash_duration * 0.5)
		tween.tween_property(button, "modulate", original_modulate, flash_duration * 0.5)
	
	# Determine failure reason
	if reason.is_empty():
		if storage_manager and not storage_manager.can_afford_item(item_id):
			reason = "Cannot afford item"
		elif storage_manager and storage_manager.get_occupied_containers().size() >= 24:
			reason = "No storage available"
		else:
			reason = "Purchase failed"
	
	DebugLogger.debug(module_name, "Purchase failed: " + item_id + " - " + reason)

func _update_button_state(item_id: String) -> void:
	var button = item_buttons.get(item_id, null)
	if not button or not storage_manager:
		return
	
	var can_afford = storage_manager.can_afford_item(item_id)
	var has_space = storage_manager.get_occupied_containers().size() < 24
	
	button.disabled = not (can_afford and has_space)
	button.modulate = Color.WHITE if can_afford else Color(0.5, 0.5, 0.5)

func _update_all_buttons() -> void:
	for item_id in item_buttons:
		_update_button_state(item_id)

func _update_requisition_display() -> void:
	if requisition_label and storage_manager:
		requisition_label.text = "Requisition: " + str(storage_manager.get_requisition())

func _on_requisition_spent(amount: int) -> void:
	_update_requisition_display()
	_update_all_buttons()

## Refresh the shop (useful after day reset)
func refresh_shop() -> void:
	_populate_shop()
	_update_requisition_display()
	
	DebugLogger.debug(module_name, "Shop refreshed")
