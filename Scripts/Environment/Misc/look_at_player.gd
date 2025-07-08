extends LookAtModifier3D

## Delay in seconds before activating the look at modifier
@export var activation_delay: float = 5.0

func _ready():
	# Register with DebugLogger
	DebugLogger.register_module("MonitorLookAt")
	
	# Start the activation timer
	await get_tree().create_timer(activation_delay).timeout
	
	# Get player reference from CommonUtils
	var player = CommonUtils.get_player()
	if not player:
		DebugLogger.log_message("MonitorLookAt", "No player found")
		return
	
	# Get the player's head node
	var player_head = player.get_node("Head")
	if not player_head:
		DebugLogger.log_message("MonitorLookAt", "No Head node found on player")
		return
	
	# Set the target node on self
	target_node = player_head.get_path()
	DebugLogger.log_message("MonitorLookAt", "Target set to player head: " + str(player_head.get_path()))
	
	# Activate self
	active = true
	DebugLogger.log_message("MonitorLookAt", "LookAtModifier3D activated")
