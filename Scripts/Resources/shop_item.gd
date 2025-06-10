# ShopItem.gd
extends Resource
class_name ShopItem

## Unique identifier for the item
@export var item_id: String = ""

## Display name in the shop
@export var item_name: String = ""

## Description shown in shop
@export var description: String = ""

## Cost in requisition points
@export var cost: int = 10

## Time in seconds before item is delivered
@export var delivery_time: float = 5.0

## Path to the scene file that gets instantiated in the container
@export_file("*.tscn") var scene_path: String = ""

## Icon for the shop UI
@export var icon: Texture2D
