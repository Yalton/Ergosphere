# CoffeeMugSpawnPoint.gd
extends Node3D
class_name CoffeeMugSpawnPoint

## Tag identifying which room this spawn point belongs to
@export var room_tag: String = "room_default"

func _ready() -> void:
	add_to_group("coffee_mug_spawn_points")
