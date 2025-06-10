# ShopDiageticUI.gd
extends DiegeticUIBase

@export var shop_ui_control: Control  # Assign the UI control with ShopUIControl.gd

func _ready() -> void:
	super._ready()
	module_name = "ShopDiageticUI"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Set interaction text
	usable_interaction_text = "Use Shop Terminal"
	interaction_text = usable_interaction_text
	
	# Connect to shop UI signals
	if shop_ui_control:
		if shop_ui_control.has_signal("purchase_successful"):
			shop_ui_control.purchase_successful.connect(_on_purchase_successful)
		if shop_ui_control.has_signal("purchase_failed"):
			shop_ui_control.purchase_failed.connect(_on_purchase_failed)
	else:
		DebugLogger.error(module_name, "No shop UI control assigned!")
	
	DebugLogger.debug(module_name, "Shop Diagetic UI initialized")

func _on_purchase_successful(item_id: String) -> void:
	DebugLogger.info(module_name, "Purchase successful: " + item_id)
	# Could add sound effects or visual feedback here

func _on_purchase_failed(item_id: String) -> void:
	DebugLogger.debug(module_name, "Purchase failed: " + item_id)
	# The UI control already handles the visual feedback

func _on_day_reset_custom() -> void:
	# Refresh shop on day reset
	if shop_ui_control and shop_ui_control.has_method("refresh_shop"):
		shop_ui_control.refresh_shop()
		DebugLogger.debug(module_name, "Shop refreshed for new day")
