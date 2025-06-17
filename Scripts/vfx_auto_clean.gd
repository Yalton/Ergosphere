extends Node
class_name VFXCleanup

## VFX cleanup component that removes effects based on visibility or max lifetime
## Uses a VisibleOnScreenTimer3D child node to track visibility time

signal cleanup_requested

## Reference to the visibility timer component
@export var visibility_timer: VisibleOnScreenTimer3D

## How long the VFX should be visible before being removed (in seconds)
@export var visible_lifetime: float = 2.0

## Maximum time before cleanup regardless of visibility (in seconds) 
@export var max_lifetime: float = 10.0

## If true, fade out the parent node before removing it
@export var fade_out: bool = false

## Fade duration in seconds (only used if fade_out is true)
@export var fade_duration: float = 1.0

var max_timer: Timer
var is_cleaning_up: bool = false

func _ready() -> void:
	# Register with DebugLogger
	DebugLogger.register_module("VFXCleanup", true)
	
	# Check if visibility timer is assigned
	if not visibility_timer:
		DebugLogger.error("VFXCleanup", "No VisibleOnScreenTimer3D assigned! Assign one in inspector.")
		return
	
	# Configure the visibility timer
	visibility_timer.required_visibility_duration = visible_lifetime
	visibility_timer.auto_reset_on_exit = false
	
	# Connect to visibility duration signal
	visibility_timer.visibility_duration_reached.connect(_on_visible_duration_reached)
	
	# Set up max lifetime timer
	max_timer = Timer.new()
	max_timer.wait_time = max_lifetime
	max_timer.one_shot = true
	max_timer.timeout.connect(_on_max_lifetime_reached)
	add_child(max_timer)
	max_timer.start()
	
	DebugLogger.debug("VFXCleanup", "Initialized - visible: %fs, max: %fs" % [visible_lifetime, max_lifetime])

func _on_visible_duration_reached(total_time: float) -> void:
	if is_cleaning_up:
		return
		
	DebugLogger.debug("VFXCleanup", "Player viewed for %fs - cleaning up" % total_time)
	_start_cleanup()

func _on_max_lifetime_reached() -> void:
	if is_cleaning_up:
		return
		
	DebugLogger.debug("VFXCleanup", "Max lifetime reached - cleaning up")
	_start_cleanup()

func _start_cleanup() -> void:
	if is_cleaning_up:
		return
		
	is_cleaning_up = true
	
	# Stop the max timer since we're cleaning up
	if max_timer and max_timer.is_valid():
		max_timer.stop()
	
	if fade_out:
		_fade_out_and_cleanup()
	else:
		_cleanup_immediately()

func _fade_out_and_cleanup() -> void:
	var parent_node = get_parent()
	if not parent_node:
		_cleanup_immediately()
		return
	
	if parent_node.has_method("set_modulate"):
		var tween = create_tween()
		tween.tween_property(parent_node, "modulate", Color(1, 1, 1, 0), fade_duration)
		tween.tween_callback(_cleanup_immediately)
		DebugLogger.debug("VFXCleanup", "Fading out over %fs" % fade_duration)
	else:
		_cleanup_immediately()

func _cleanup_immediately() -> void:
	DebugLogger.debug("VFXCleanup", "Cleanup complete")
	cleanup_requested.emit()

## Tell spawners we handle our own cleanup
func handles_own_cleanup() -> bool:
	return true
