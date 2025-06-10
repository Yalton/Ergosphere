# ShopItem.gd
extends Resource
class_name ShopItem

## Unique identifier for this item
@export var item_id: String = ""

## Display name shown in the shop
@export var display_name: String = ""

## Item description
@export_multiline var description: String = ""

## Cost in requisition points
@export var cost: int = 100

## Delivery time in seconds
@export var delivery_time: float = 30.0

## Category for shop organization (General or Replacement Parts)
@export_enum("General", "Replacement Parts") var category: String = "General"

## Path to the scene that will be instantiated
@export_file("*.tscn") var scene_path: String = ""

## Icon texture (optional)
@export var icon: Texture2D

## Get delivery time as formatted text
func delivery_time_text() -> String:
	if delivery_time < 60:
		return str(int(delivery_time)) + "s delivery"
	else:
		var minutes = int(delivery_time / 60)
		var seconds = int(delivery_time) % 60
		if seconds == 0:
			return str(minutes) + "m delivery"
		else:
			return str(minutes) + "m " + str(seconds) + "s delivery"
