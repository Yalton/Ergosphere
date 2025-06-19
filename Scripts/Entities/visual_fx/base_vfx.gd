extends Node
class_name BaseVisualEffect

## Base class for all visual effects
## Each effect handler extends this and implements the effect logic

signal effect_started()
signal effect_finished()

## Unique identifier for this effect
@export var effect_id: String = ""
## Display name for debugging
@export var effect_name: String = ""
## Which compositor effect index this uses (-1 if none)
@export var compositor_index: int = -1
## Whether to use blink transition (except for blink itself)
@export var use_blink_transition: bool = true

## Whether this effect is currently active
var is_active: bool = false
## Module name for debug logging
var module_name: String = "BaseVisualEffect"

func _ready() -> void:
	if effect_id.is_empty():
		effect_id = name.to_lower().replace(" ", "_")
	if effect_name.is_empty():
		effect_name = name
	
	module_name = effect_name + "Effect"
	DebugLogger.register_module(module_name, true)

## Main method to invoke the effect
func invoke_effect(startup: float, duration: float, wind_down: float) -> void:
	if is_active:
		DebugLogger.warning(module_name, "Effect already active")
		return
	
	is_active = true
	effect_started.emit()
	DebugLogger.info(module_name, "Starting effect - startup: %f, duration: %f, wind_down: %f" % [startup, duration, wind_down])
	
	# Handle blink transition for non-blink effects
	if use_blink_transition and effect_id != "blink":
		await _do_blink_transition(true)
	
	# Execute the three phases
	await _startup_phase(startup)
	await _duration_phase(duration)
	await _wind_down_phase(wind_down)
	
	# Handle blink transition out
	if use_blink_transition and effect_id != "blink":
		await _do_blink_transition(false)
	
	is_active = false
	effect_finished.emit()
	DebugLogger.info(module_name, "Effect finished")

## Helper to do blink transition
func _do_blink_transition(starting: bool) -> void:
	var vfx_manager = get_parent()
	if vfx_manager and vfx_manager.has_method("invoke_effect"):
		# Quick blink transition
		vfx_manager.invoke_effect("blink", 0.1, 0.05, 0.1)
		await get_tree().create_timer(0.15).timeout  # Wait for blink to reach peak

## Override in child classes - handles the startup/fade-in phase
func _startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Default startup phase - override in child class")
	if time > 0:
		await get_tree().create_timer(time).timeout

## Override in child classes - handles the main duration phase
func _duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Default duration phase - override in child class")
	if time > 0:
		await get_tree().create_timer(time).timeout

## Override in child classes - handles the wind-down/fade-out phase
func _wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Default wind down phase - override in child class")
	if time > 0:
		await get_tree().create_timer(time).timeout

## Stop the effect immediately (useful for cleanup)
func stop_immediately() -> void:
	if not is_active:
		return
	
	DebugLogger.info(module_name, "Stopping effect immediately")
	
	# Call cleanup
	_cleanup()
	
	is_active = false
	effect_finished.emit()

## Override in child classes for any cleanup needed
func _cleanup() -> void:
	pass

## Helper to get the compositor effect from player camera
func get_compositor_effect() -> CompositorEffect:
	if compositor_index < 0:
		return null
		
	var player_cam = CommonUtils.get_player_camera()
	if not player_cam:
		DebugLogger.error(module_name, "No player camera found")
		return null
	
	var compositor = player_cam.compositor
	if not compositor:
		DebugLogger.error(module_name, "No compositor on player camera")
		return null
	
	var effects = compositor.compositor_effects
	if compositor_index >= effects.size():
		DebugLogger.error(module_name, "Compositor index %d out of range" % compositor_index)
		return null
	
	return effects[compositor_index]
