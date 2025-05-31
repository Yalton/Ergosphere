# TelescopeDiegeticUI.gd
extends DiegeticUIBase

# Signal that relays telescope position to external systems
signal telescope_adjusted(x_normalized: float, y_normalized: float)

@export var telescope_ui_control: Control  # Assign the TelescopeController node

func _ready() -> void:
	super._ready()
	module_name = "TelescopeDiegeticUI"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Connect to the telescope controller's signal
	if telescope_ui_control:
		if telescope_ui_control.has_signal("telescope_position_changed"):
			telescope_ui_control.telescope_position_changed.connect(_on_telescope_position_changed)
			DebugLogger.debug(module_name, "Connected to telescope controller signal")
		else:
			DebugLogger.error(module_name, "Telescope controller doesn't have telescope_position_changed signal!")
	else:
		DebugLogger.error(module_name, "No telescope controller assigned!")
	
	DebugLogger.debug(module_name, "Telescope Diegetic UI initialized")

func _on_telescope_position_changed(x_normalized: float, y_normalized: float) -> void:
	DebugLogger.debug(module_name, "Telescope position changed - X: %.2f, Y: %.2f" % [x_normalized, y_normalized])
	
	# Relay the signal to external listeners (like the physical telescope)
	telescope_adjusted.emit(x_normalized, y_normalized)

# Optional: Get current telescope alignment status
func is_telescope_aligned() -> bool:
	if telescope_ui_control and telescope_ui_control.has_method("is_telescope_aligned"):
		return telescope_ui_control.is_telescope_aligned()
	return false

# Optional: Reset telescope alignment
func reset_telescope_alignment() -> void:
	if telescope_ui_control and telescope_ui_control.has_method("reset_alignment"):
		telescope_ui_control.reset_alignment()
		DebugLogger.debug(module_name, "Telescope alignment reset")
