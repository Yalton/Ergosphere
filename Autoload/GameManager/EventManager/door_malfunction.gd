extends EventHandler
class_name DoorResistanceEvent

## Event that causes a nearby door to get stuck while opening

@export_group("Resistance Settings")
## How far the door opens before getting stuck (0.0 to 1.0)
@export var stuck_at_progress: float = 0.25
## How long the door stays stuck in seconds
@export var stuck_duration: float = 0.5
## Maximum distance to find a door from the player
@export var max_door_distance: float = 10.0
## Group name for door wrappers
@export var door_wrapper_group: String = "door_wrappers"

func _ready() -> void:
	super._ready()
	module_name = "DoorResistanceEvent"
	
	# Define which events this handler processes
	handled_event_ids = ["door_resistance", "sticky_door", "door_stuck"]
	
	DebugLogger.debug(module_name, "DoorResistanceEvent ready")

func can_execute() -> bool:
	# First check base requirements
	if not super.can_execute():
		return false
	
	# Find nearest closed door to player
	var nearest_door = _find_nearest_closed_door()
	if not nearest_door:
		DebugLogger.warning(module_name, "No valid closed door found near player")
		return false
	
	return true

func execute() -> bool:
	# Call base implementation
	if not super.execute():
		return false
	
	# Find nearest closed door
	var door = _find_nearest_closed_door()
	if not door:
		DebugLogger.error(module_name, "No door found during execution")
		return false
	
	DebugLogger.info(module_name, "Setting resistance on door: " + door.get_parent().name)
	
	# Tell the door to resist next time it opens
	door.set_resistance_next_open(stuck_at_progress, stuck_duration)
	
	# End immediately - the door will handle the rest
	end()
	
	return true

func _find_nearest_closed_door() -> Node:
	var player = GameManager.get_player()
	if not player:
		return null
	
	var door_wrappers = get_tree().get_nodes_in_group(door_wrapper_group)
	var nearest_door = null
	var nearest_distance = max_door_distance
	
	for wrapper in door_wrappers:
		if not wrapper.is_inside_tree() or not wrapper.door:
			continue
		
		var door = wrapper.door
		
		# Skip if door is already open or locked
		if door.is_open or door.is_locked:
			continue
		
		# Skip if door is not automatic
		if not door is AutomaticStationDoor:
			continue
		
		var distance = player.global_position.distance_to(wrapper.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_door = door
	
	return nearest_door

func end() -> void:
	DebugLogger.info(module_name, "Door resistance event configured")
	
	# Call base implementation
	super.end()
