extends VisibleOnScreenNotifier3D
class_name VisibleOnScreenTimer3D

## Timer component that tracks how long an object has been visible on screen
## Built on top of VisibleOnScreenNotifier3D for automatic visibility detection

signal time_on_screen_changed(current_time: float)
signal visibility_duration_reached(total_time: float)

## Whether debug logging is enabled for this component
@export var enable_debug: bool = false

## Duration in seconds that must be visible before triggering visibility_duration_reached signal
@export var required_visibility_duration: float = 0.0

## Whether the timer should auto-reset when the object exits the screen
@export var auto_reset_on_exit: bool = true

var module_name: String = "VisibleOnScreenTimer3D"
var is_currently_visible: bool = false
var total_time_visible: float = 0.0
var current_session_start: float = 0.0
var duration_reached: bool = false

func _ready() -> void:
	# Register with DebugLogger
	DebugLogger.register_module(module_name, enable_debug)
	
	# Connect to parent class signals
	screen_entered.connect(_on_screen_entered)
	screen_exited.connect(_on_screen_exited)
	
	DebugLogger.debug(module_name, "Timer initialized. Required duration: %f seconds" % required_visibility_duration)

func _on_screen_entered() -> void:
	is_currently_visible = true
	current_session_start = Time.get_time_dict_from_system()["hour"] * 3600.0 + Time.get_time_dict_from_system()["minute"] * 60.0 + Time.get_time_dict_from_system()["second"]
	DebugLogger.debug(module_name, "Entered screen - starting timer")

func _on_screen_exited() -> void:
	if is_currently_visible:
		_update_total_time()
		is_currently_visible = false
		
		DebugLogger.debug(module_name, "Exited screen - total time visible: %f seconds" % total_time_visible)
		
		if auto_reset_on_exit:
			reset_timer()
			DebugLogger.debug(module_name, "Timer auto-reset on exit")

func _process(delta: float) -> void:
	if is_currently_visible:
		_update_total_time()
		time_on_screen_changed.emit(total_time_visible)
		
		# Check if we've reached the required duration
		if required_visibility_duration > 0.0 and not duration_reached and total_time_visible >= required_visibility_duration:
			duration_reached = true
			visibility_duration_reached.emit(total_time_visible)
			DebugLogger.debug(module_name, "Required visibility duration reached: %f seconds" % total_time_visible)

func _update_total_time() -> void:
	if is_currently_visible:
		var current_time = Time.get_time_dict_from_system()["hour"] * 3600.0 + Time.get_time_dict_from_system()["minute"] * 60.0 + Time.get_time_dict_from_system()["second"]
		var session_time = current_time - current_session_start
		total_time_visible += session_time
		current_session_start = current_time

## Get the current total time the object has been visible
func get_total_time_visible() -> float:
	if is_currently_visible:
		_update_total_time()
	return total_time_visible

## Reset the timer to zero
func reset_timer() -> void:
	total_time_visible = 0.0
	duration_reached = false
	if is_currently_visible:
		current_session_start = Time.get_time_dict_from_system()["hour"] * 3600.0 + Time.get_time_dict_from_system()["minute"] * 60.0 + Time.get_time_dict_from_system()["second"]
	DebugLogger.debug(module_name, "Timer reset")

## Check if the object is currently visible on screen
func is_visible_on_screen() -> bool:
	return is_currently_visible
