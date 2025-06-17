# TeleportationEventHandler.gd
extends EventHandler
class_name TeleportationEventHandler

## Handles silent teleportation events between specific station locations
## Designed to disorient players by teleporting them between similar areas

@export_group("Teleportation Settings")
## Distance threshold for detecting if player is near a teleport point
@export var detection_radius: float = 2.0

## Cooldown between teleports to prevent rapid teleportation
@export var teleport_cooldown: float = 3.0

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
var last_teleport_time: float = 0.0
var is_active: bool = false

func _ready() -> void:
	super._ready()
	module_name = "TeleportationEventHandler"
	
	# Define which events this handler processes
	handled_event_ids = ["disorienting_teleport", "spatial_anomaly", "teleport_malfunction"]
	
	DebugLogger.debug(module_name, "TeleportationEventHandler ready")

func _process(delta: float) -> void:
	if not is_active or not player_node:
		return
		
	# Check if enough time has passed since last teleport
	if Time.get_ticks_msec() / 1000.0 - last_teleport_time < teleport_cooldown:
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
	
	# Activate teleportation system silently
	is_active = true

func _on_complete(event_data: EventData, state_manager: StateManager) -> void:
	## Handle teleportation event completion
	DebugLogger.info(module_name, "Completing teleportation event: %s" % event_data.event_id)
	
	# Deactivate teleportation system
	is_active = false

func _teleport_player(shift: Vector3) -> void:
	## Silently teleport the player to the new position
	if not player_node:
		return
		
	DebugLogger.debug(module_name, "Silently teleporting player with shift %s" % shift)
	
	# Force drop any carried item
	if player_interaction and player_interaction.carried_object:
		DebugLogger.debug(module_name, "Forcing player to drop carried object before teleport")
		player_interaction.carried_object.leave()
		# Small delay to ensure clean drop
		await player_node.get_tree().create_timer(0.1).timeout
	
	# Calculate new position
	var new_position = player_node.global_position + shift
	
	# Perform the teleportation silently
	player_node.global_position = new_position
	
	# Update last teleport time
	last_teleport_time = Time.get_ticks_msec() / 1000.0
	
	DebugLogger.info(module_name, "Player teleported to %s" % new_position)

func _find_player_node() -> Node3D:
	## Find the player node in the scene
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		return players[0]
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
