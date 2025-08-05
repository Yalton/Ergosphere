extends EventHandler
class_name DoorResistanceEvent

## Event that causes a nearby door to get stuck while opening

@export_group("Resistance Settings")
## How far the door opens before getting stuck (0.0 to 1.0)
@export var stuck_at_progress: float = 0.25
## How long the door stays stuck in seconds
@export var stuck_duration: float = 0.5
## Maximum distance to find a door from the player
@export var max_door_distance: float = 1000.0
## Group name for door wrappers
@export var door_wrapper_group: String = "door_wrappers"

func _ready() -> void:
	# Define which events this handler processes
	handled_event_ids = ["door_malfunction"]

func _can_execute_internal() -> Dictionary:
	# Find nearest closed door to player
	var nearest_door = _find_nearest_closed_door()
	if not nearest_door:
		return {"success": false, "message": "No valid closed door found within " + str(max_door_distance) + " units of player"}
	
	# Check if door has the required method
	if not nearest_door.has_method("set_resistance_next_open"):
		return {"success": false, "message": "Door does not support resistance functionality"}
	
	return {"success": true, "message": "OK"}

func _execute_internal() -> Dictionary:
	# Find nearest closed door
	var door = _find_nearest_closed_door()
	if not door:
		return {"success": false, "message": "No door found during execution"}
	
	# Tell the door to resist next time it opens
	door.set_resistance_next_open(stuck_at_progress, stuck_duration)
	
	# End immediately - the door will handle the rest
	end()
	
	return {"success": true, "message": "OK"}

func _find_nearest_closed_door() -> Node:
	var player = CommonUtils.get_player()
	if not player:
		return null
	
	var door_wrappers : Array[Node] = get_tree().get_nodes_in_group(door_wrapper_group)
	
	print("Found ", door_wrappers.size(), " door wrappers")
	var nearest_door = null
	var nearest_distance = max_door_distance
	
	for wrapper in door_wrappers:
		var door = wrapper.door
		
		var distance = player.global_position.distance_to(wrapper.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_door = door
	
	return nearest_door

func end() -> void:
	# Call base implementation
	super.end()
