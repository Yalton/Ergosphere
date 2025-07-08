# warp.gd
extends EventHandler
class_name WarpEvent

## Teleports the player to a random location

@export_group("Warp Settings")
## Group name for warp destinations
@export var warp_destination_group: String = "warp_destinations"
## Minimum distance from current position (to ensure noticeable warp)
@export var min_warp_distance: float = 5.0
## Sound to play when warping
@export var warp_sound: AudioStream
## Visual effect duration (fade to black and back)
@export var fade_duration: float = 0.5

func _ready() -> void:
	super._ready()
	module_name = "WarpEvent"
	
	# Events this handler processes
	handled_event_ids = ["warp", "player_teleport"]
	
	DebugLogger.debug(module_name, "WarpEvent ready")

func can_execute() -> bool:
	# First check base requirements
	if not super.can_execute():
		return false
	
	# Check if player exists
	var player = CommonUtils.get_player()
	if not player:
		DebugLogger.warning(module_name, "No player found")
		return false
	
	# Check if warp destinations exist
	var destinations = get_tree().get_nodes_in_group(warp_destination_group)
	if destinations.is_empty():
		DebugLogger.warning(module_name, "No warp destinations found in group: %s" % warp_destination_group)
		return false
	
	return true

func execute() -> bool:
	# Call base implementation
	if not super.execute():
		return false
	
	var player = CommonUtils.get_player()
	if not player:
		DebugLogger.error(module_name, "No player found during execution")
		return false
	
	var destination = _find_valid_destination(player)
	if not destination:
		DebugLogger.warning(module_name, "No valid warp destination found")
		return false
	
	# Perform the warp
	_warp_player(player, destination)
	
	return true

func end() -> void:
	DebugLogger.info(module_name, "Warp event completed")
	
	# Call base implementation
	super.end()

func _find_valid_destination(player: Node3D) -> Node3D:
	## Find a valid warp destination that meets distance requirements
	var destinations = get_tree().get_nodes_in_group(warp_destination_group)
	var valid_destinations = []
	
	for dest in destinations:
		if dest is Node3D and dest != player:
			var distance = player.global_position.distance_to(dest.global_position)
			if distance >= min_warp_distance:
				valid_destinations.append(dest)
	
	if valid_destinations.is_empty():
		# If no destinations meet distance requirement, use any destination
		for dest in destinations:
			if dest is Node3D and dest != player:
				valid_destinations.append(dest)
	
	if valid_destinations.is_empty():
		return null
	
	# Pick random destination
	return valid_destinations[randi() % valid_destinations.size()]

func _warp_player(player: Node3D, destination: Node3D) -> void:
	## Actually teleport the player with effects
	DebugLogger.info(module_name, "Warping player to: %s" % destination.name)
	
	# Play warp sound
	if warp_sound:
		play_audio(warp_sound)
	
	# Get UI controller for fade effect
	var ui_controller = _find_ui_controller(player)
	
	if ui_controller and ui_controller.has_method("fade_to_black"):
		# Fade to black
		ui_controller.fade_to_black(fade_duration)
		
		# Wait for fade
		await get_tree().create_timer(fade_duration).timeout
		
		# Teleport player
		player.global_position = destination.global_position
		if destination.has_method("get_rotation"):
			player.rotation = destination.rotation
		
		# Fade back in
		ui_controller.fade_from_black(fade_duration)
		
		# End event after fade completes
		await get_tree().create_timer(fade_duration).timeout
	else:
		# No fade effect, just teleport instantly
		player.global_position = destination.global_position
		if destination.has_method("get_rotation"):
			player.rotation = destination.rotation
		
		# Brief disorientation pause
		await get_tree().create_timer(0.5).timeout
	
	# End the event
	if is_active:
		end()

func _find_ui_controller(player: Node) -> Node:
	## Find the UI controller (might be child of player or in scene)
	# First check player children
	var ui_controller = player.get_node_or_null("UIController")
	if ui_controller:
		return ui_controller
	
	# Check for PlayerUI in scene
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if not ui_controllers.is_empty():
		return ui_controllers[0]
	
	# Try to find by class
	for node in get_tree().get_nodes_in_group("player"):
		for child in node.get_children():
			if child.has_method("fade_to_black"):
				return child
	
	return null
