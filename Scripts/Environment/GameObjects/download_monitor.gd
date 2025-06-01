# DownloadDiegeticUI.gd
extends DiegeticUIBase

signal download_completed

@export var download_ui_control: Control  # Assign the UI control with DownloadUIControl.gd


func _ready() -> void:
	super._ready()
	module_name = "DownloadDiegeticUI"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Connect to the UI control's signal
	if download_ui_control:
		if download_ui_control.has_signal("download_completed"):
			download_ui_control.download_completed.connect(_on_ui_download_completed)
			DebugLogger.debug(module_name, "Connected to UI control download signal")
		else:
			DebugLogger.error(module_name, "UI control doesn't have download_completed signal!")
	else:
		DebugLogger.error(module_name, "No download UI control assigned!")
	
	DebugLogger.debug(module_name, "Download Diegetic UI initialized")

func _on_ui_download_completed() -> void:
	DebugLogger.debug(module_name, "UI download completed - relaying signal")
	
	# Relay the signal to external listeners (like the server)
	download_completed.emit()
