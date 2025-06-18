# TeleportationEventHandler.gd
extends EventHandler
class_name TeleportationEventHandler

## Handles one-time teleportation events between specific station locations
## Waits for player to enter radius before teleporting once

@export_group("Teleportation Settings")
## Distance threshold for detecting if player is near a teleport point
@export var detection_radius: float = 2.0

# Teleport point configurations
var teleport_points: Array[Dictionary] = [
	{
		"position": Vector3(-35, -4, -17),
		"shift": Vector3(0, 0, 47)  # Shift +47 in Z
	},
	{
		"position": Vector3(-35, -4, 30),
		"shift": Vector3(0, 0, -47)  # Shift -47 in Z
	},
	{
		"position": Vector3(35, -4, -17),
		"shift": Vector3(0, 0, 47)  # Shift +47 in Z
	},
	{
		"position": Vector3(35, -4, 30),
		"shift": Vector3(0, 0, -47)  # Shift -47 in Z
	}
]

var player_node: Node3D = null
var player_interaction: PlayerInteractionComponent = null
var is_active: bool = false
var has_teleported: bool = false

func _ready() -> void:
	module_name = "TeleportationEventHandler"
	super._ready()
	DebugLogger.register_module(module_name)
	
	# Define which events this handler processes
	handled_event_ids = ["warp"]
	
	DebugLogger.debug(module_name, "TeleportationEventHandler ready")

func _process(delta: float) -> void:
	if not is_active or has_teleported or not player_node:
		return
	
	# Check player proximity to teleport points
	var player_pos = player_node.global_position
	
	for point in teleport_points:
		var distance = player_pos.distance_to(point["position"])
		
		if distance <= detection_radius:
			_teleport_player(point["shift"])
			break

func _on_execute(event_data: EventData, state_manager: StateManager) -> void:
	## Handle teleportation event execution
	DebugLogger.info(module_name, "Executing teleportation event: %s" % event_data.event_id)
	
	# Find player node
	player_node = _find_player_node()
	if not player_node:
		DebugLogger.error(module_name, "Could not find player node")
		return
	
	# Find player interaction component
	player_interaction = _find_player_interaction()
	
	# Activate teleportation system and wait for player
	is_active = true
	has_teleported = false
	DebugLogger.debug(module_name, "Waiting for player to enter teleport radius")

func _on_complete(event_data: EventData, state_manager: StateManager) -> void:
	## Handle teleportation event completion
	DebugLogger.info(module_name, "Completing teleportation event: %s" % event_data.event_id)
	
	# Deactivate teleportation system
	is_active = false

func _teleport_player(shift: Vector3) -> void:
	## Silently teleport the player using the shift vector once
	if not player_node or has_teleported:
		return
		
	DebugLogger.debug(module_name, "Silently teleporting player with shift %s" % shift)
	
	# Mark as teleported first to prevent double teleports
	has_teleported = true
	
	# Force drop any carried item
	if player_interaction and player_interaction.carried_object:
		DebugLogger.debug(module_name, "Forcing player to drop carried object before teleport")
		player_interaction.carried_object.leave()
		# Small delay to ensure clean drop
		await player_node.get_tree().create_timer(0.1).timeout
	
	# Stop player movement completely
	if player_node is CharacterBody3D:
		player_node.velocity = Vector3.ZERO
	
	# Apply the shift to current position
	var old_position = player_node.global_position
	var new_position = old_position + shift
	
	# Perform the teleportation silently
	player_node.global_position = new_position
	
	DebugLogger.info(module_name, "Player teleported from %s to %s - teleportation complete" % [old_position, new_position])

func _find_player_node() -> Node3D:
	## Find the player node in the scene
	if CommonUtils.get_player():
		return CommonUtils.get_player()
	return null

func _find_player_interaction() -> PlayerInteractionComponent:
	## Find the player interaction component
	if not player_node:
		return null
		
	# Try to find PlayerInteractionComponent as child
	for child in player_node.get_children():
		if child is PlayerInteractionComponent:
			return child
	
	# Try to find in nested structure (like Head/Camera3D)
	var interaction = player_node.find_child("PlayerInteractionComponent", true)
	if interaction and interaction is PlayerInteractionComponent:
		return interaction
		
	return null
