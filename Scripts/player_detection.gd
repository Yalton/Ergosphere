extends Node3D

## Debug settings
@export var enable_debug: bool = true
var module_name: String = "PlayerDetection"
var current_room: String = "None"

func _ready() -> void:
	# Find all event nodes
	DebugLogger.register_module(module_name, enable_debug)
	for child in get_children():
		if child is PlayerScanner:
			child.player_in_room.connect(_on_player_in_room)
			#DebugLogger.debug(module_name, "Signal connected with " + str(child.room_id))


func _on_player_in_room(room_id: String):
	if current_room == room_id: 
		return
	current_room = room_id
	DebugLogger.debug(module_name, "Player is is " + str(current_room) + " room id was " + str(room_id))
