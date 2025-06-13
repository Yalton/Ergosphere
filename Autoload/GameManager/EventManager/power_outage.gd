# PowerOutageHandler.gd
extends EventHandler
class_name PowerOutageHandler

## Power outage event handler for the new event system
## Uses effects manager for all power-related visual and audio effects

func _ready() -> void:
	super._ready()
	module_name = "PowerOutageHandler"
	
	# Define which events this handler processes
	handled_event_ids = ["power_outage", "partial_power_loss", "backup_power_failure"]
	
	DebugLogger.debug(module_name, "PowerOutageHandler ready")

func _on_execute(event_data: EventData, state_manager: StateManager) -> void:
	## Handle power outage event execution
	DebugLogger.info(module_name, "Executing power event: %s" % event_data.event_id)
	
	match event_data.event_id:
		"power_outage":
			_handle_full_power_outage(event_data, state_manager)
		"partial_power_loss":
			_handle_partial_power_loss(event_data, state_manager)
		"backup_power_failure":
			_handle_backup_power_failure(event_data, state_manager)

func _on_complete(event_data: EventData, state_manager: StateManager) -> void:
	## Handle power outage event completion
	DebugLogger.info(module_name, "Completing power event: %s" % event_data.event_id)
	
	match event_data.event_id:
		"power_outage":
			_complete_full_power_outage(event_data, state_manager)
		"partial_power_loss":
			_complete_partial_power_loss(event_data, state_manager)
		"backup_power_failure":
			_complete_backup_power_failure(event_data, state_manager)

func _handle_full_power_outage(event_data: EventData, state_manager: StateManager) -> void:
	## Handle full power outage
	DebugLogger.debug(module_name, "Full power outage started")
	
	# Use effects manager for all power-related effects
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if effects_manager:
		effects_manager.kill_power()
	else:
		DebugLogger.error(module_name, "Could not find effects manager")
	
	# Show warning message
	if CommonUtils:
		CommonUtils.send_player_hint("", "WARNING: Main Power System Failure")
	
	# Trigger emergency task if task system is available
	if GameManager and GameManager.task_manager:
		GameManager.task_manager.trigger_emergency_task("restore_power")
	
	DebugLogger.info(module_name, "Power outage started - emergency lighting active")

func _handle_partial_power_loss(event_data: EventData, state_manager: StateManager) -> void:
	## Handle partial power loss
	DebugLogger.debug(module_name, "Partial power loss started")
	
	# Use effects manager for partial power effects if it supports it
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if effects_manager:
		# For now, just kill power - could extend effects manager to handle partial power
		effects_manager.kill_power()
	
	# Show warning
	if CommonUtils:
		CommonUtils.send_player_hint("", "WARNING: Partial Power Loss Detected")

func _handle_backup_power_failure(event_data: EventData, state_manager: StateManager) -> void:
	## Handle backup power system failure
	DebugLogger.debug(module_name, "Backup power failure started")
	
	# Could extend effects manager to handle backup power states
	# For now, just show warning
	if CommonUtils:
		CommonUtils.send_player_hint("", "WARNING: Backup Power System Failure")

func _complete_full_power_outage(event_data: EventData, state_manager: StateManager) -> void:
	## Complete full power outage (power restored)
	DebugLogger.debug(module_name, "Full power outage completed - power restored")
	
	# Use effects manager to restore power
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if effects_manager:
		effects_manager.restore_power()
	else:
		DebugLogger.error(module_name, "Could not find effects manager")
	
	# Show restoration message
	if CommonUtils:
		CommonUtils.send_player_hint("", "Power Systems Restored")
	
	DebugLogger.info(module_name, "Power restored - normal lighting active")

func _complete_partial_power_loss(event_data: EventData, state_manager: StateManager) -> void:
	## Complete partial power loss
	DebugLogger.debug(module_name, "Partial power loss completed")
	
	# Use effects manager to restore power
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if effects_manager:
		effects_manager.restore_power()
	
	if CommonUtils:
		CommonUtils.send_player_hint("", "Power Systems Restored")

func _complete_backup_power_failure(event_data: EventData, state_manager: StateManager) -> void:
	## Complete backup power failure
	DebugLogger.debug(module_name, "Backup power failure completed")
	
	# Use effects manager to restore power
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if effects_manager:
		effects_manager.restore_power()
	
	if CommonUtils:
		CommonUtils.send_player_hint("", "Backup Power Systems Restored")
