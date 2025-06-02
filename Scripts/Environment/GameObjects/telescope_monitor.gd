# TelescopeDiegeticUI.gd
extends DiegeticUIBase

# Signal that relays telescope position to external systems
signal telescope_adjusted(x_normalized: float, y_normalized: float)
signal telescope_aligned()

@export var telescope_ui_control: Control  # Assign the TelescopeController node

var task_aware_component: TaskAwareComponent
var alignment_completed: bool = false

func _ready() -> void:
	super._ready()
	module_name = "TelescopeDiegeticUI"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Find task aware component
	task_aware_component = get_node_or_null("TaskAwareComponent")
	
	# Add to telescope_terminals group for task system
	add_to_group("telescope_terminals")
	
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
	
	# Check if telescope is now aligned
	if telescope_ui_control and telescope_ui_control.has_method("is_telescope_aligned"):
		var is_aligned = telescope_ui_control.is_telescope_aligned()
		if is_aligned and not alignment_completed:
			alignment_completed = true
			_on_telescope_aligned()

func _on_telescope_aligned() -> void:
	DebugLogger.info(module_name, "Telescope alignment completed")
	
	# Complete the task if we have a task component
	if task_aware_component:
		task_aware_component.complete_task()
	
	# Emit signal for other systems
	telescope_aligned.emit()

# Optional: Get current telescope alignment status
func is_telescope_aligned() -> bool:
	if telescope_ui_control and telescope_ui_control.has_method("is_telescope_aligned"):
		return telescope_ui_control.is_telescope_aligned()
	return false

# Optional: Reset telescope alignment
func reset_telescope_alignment() -> void:
	if telescope_ui_control and telescope_ui_control.has_method("reset_alignment"):
		telescope_ui_control.reset_alignment()
		alignment_completed = false
		DebugLogger.debug(module_name, "Telescope alignment reset")
