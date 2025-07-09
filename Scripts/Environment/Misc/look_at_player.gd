extends LookAtModifier3D

## Delay in seconds before activating the look at modifier
@export var activation_delay: float = 5.0

## Marker node to follow when UI is locked
@export var marker: Node3D

var player_head: Node3D
var parent_diegetic_ui: DiegeticUIBase
var module_name: String = "MonitorLookAt"

func _ready():
	# Register with DebugLogger
	DebugLogger.register_module(module_name)
	
	# Get parent diegetic UI
	parent_diegetic_ui = get_parent_node_of_type(self, "DiegeticUIBase")
	if not parent_diegetic_ui:
		DebugLogger.log_message(module_name, "No parent DiegeticUIBase found")
	
	# Start the activation timer
	await get_tree().create_timer(activation_delay).timeout
	
	# Get player reference from CommonUtils
	var player = CommonUtils.get_player()
	if not player:
		DebugLogger.log_message(module_name, "No player found")
		return
	
	# Get the player's head node
	player_head = player.get_node("Head")
	if not player_head:
		DebugLogger.log_message(module_name, "No Head node found on player")
		return
	
	# Set initial target based on UI state
	_update_target()
	
	# Activate self
	active = true
	DebugLogger.log_message(module_name, "LookAtModifier3D activated")

func _physics_process(_delta: float) -> void:
	if not active:
		return
	
	# Update target based on diegetic UI state
	_update_target()

func _update_target() -> void:
	# Check if parent diegetic UI is disabled/locked
	var ui_disabled = false
	if parent_diegetic_ui and parent_diegetic_ui.is_disabled:
		ui_disabled = true
	
	# Switch between player head and marker based on UI disabled state
	if ui_disabled and marker:
		if target_node != marker.get_path():
			target_node = marker.get_path()
			DebugLogger.log_message(module_name, "Diegetic UI disabled - switching to marker: " + str(marker.get_path()))
	elif player_head:
		if target_node != player_head.get_path():
			target_node = player_head.get_path()
			DebugLogger.log_message(module_name, "Diegetic UI enabled - switching to player head: " + str(player_head.get_path()))

func get_parent_node_of_type(node: Node, name: String) -> Node:
	var current = node.get_parent()
	while current:
		if current.get_class() == name or (current.has_method("is_class") and current.is_class(name)):
			return current
		current = current.get_parent()
	return null
