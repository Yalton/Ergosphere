# DownloadDiegeticUI.gd
extends DiegeticUIBase

signal download_completed

@export var download_ui_control: Control  # Assign the UI control with DownloadUIControl.gd


func _ready() -> void:
	super._ready()
	module_name = "DownloadDiegeticUI"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Find task aware component
	#task_aware_component = get_node_or_null("TaskAwareComponent")
	#task_aware_component.task_availability_changed.connect(_on_availability_change)
	# Add to download_terminals group for task system
	add_to_group("download_terminals")
	
	# Connect to the UI control's signal
	if download_ui_control:
		if download_ui_control.has_signal("download_completed"):
			download_ui_control.download_completed.connect(_on_ui_download_completed)
			DebugLogger.debug(module_name, "Connected to UI control download signal")
		else:
			DebugLogger.error(module_name, "UI control doesn't have download_completed signal!")
	else:
		DebugLogger.error(module_name, "No download UI control assigned!")
	
	# Connect to task completion to check when telescope is aligned
	if GameManager and GameManager.task_manager:
		GameManager.task_manager.task_completed.connect(_on_task_completed)
	
	# Initial check of availability
	_check_availability()
	
	DebugLogger.debug(module_name, "Download Diegetic UI initialized")

func _on_task_completed(task_id: String) -> void:
	if task_id == "allign_telescope":
		_check_availability()

func _check_availability() -> void:
	# Only enable if telescope alignment is complete
	if GameManager and GameManager.task_manager:
		var telescope_aligned = GameManager.task_manager.is_task_completed("allign_telescope")
		set_ui_enabled(telescope_aligned)
		
		DebugLogger.debug(module_name, "Checked availability - telescope aligned: " + str(telescope_aligned))

func _on_ui_download_completed() -> void:
	DebugLogger.debug(module_name, "UI download completed - relaying signal")
	
	# Complete the task if we have a task component
	if task_aware_component:
		task_aware_component.complete_task()
	
	# Relay the signal to external listeners (like the server)
	download_completed.emit()

func _on_availability_change(available: bool): 
	DebugLogger.debug(module_name, "Received _on_availability_change, value was " + str(available))
	set_ui_enabled(available)
