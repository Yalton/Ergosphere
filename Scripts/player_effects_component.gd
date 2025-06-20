extends Node
class_name VisualEffectsManager

## Manages all visual effects similar to EventManager
## Child nodes should be effect handlers that extend BaseVisualEffect

signal effect_started(effect_id: String)
signal effect_finished(effect_id: String)

@export_group("Effect Settings")
## Whether to allow multiple effects simultaneously
@export var allow_simultaneous: bool = true
## Maximum simultaneous effects (-1 for unlimited)
@export var max_simultaneous: int = 3

@export_group("Camera Reference")
## Player camera reference - set this from the player script
@export var player_camera: Camera3D

## Module name for debug logging
var module_name: String = "VisualEffectsManager"
## Dictionary of effect handlers by ID
var effect_handlers: Dictionary = {}
## Currently active effects
var active_effects: Array[String] = []

func _ready() -> void:
	DebugLogger.register_module(module_name, true)
	
	# Add to group for easy finding
	add_to_group("visual_effects_manager")
	
	# Discover effect handlers
	_discover_effect_handlers()
	
	DebugLogger.info(module_name, "Visual effects manager ready with %d handlers" % effect_handlers.size())

func _discover_effect_handlers() -> void:
	## Find all child nodes that are effect handlers
	for child in get_children():
		if child is BaseVisualEffect:
			var handler = child as BaseVisualEffect
			
			if handler.effect_id.is_empty():
				DebugLogger.warning(module_name, "Effect handler %s has no ID" % handler.name)
				continue
			
			# Pass camera reference to the handler
			handler.player_camera = player_camera
			
			effect_handlers[handler.effect_id] = handler
			
			# Connect signals
			handler.effect_started.connect(_on_effect_started.bind(handler.effect_id))
			handler.effect_finished.connect(_on_effect_finished.bind(handler.effect_id))
			
			DebugLogger.debug(module_name, "Registered effect handler: %s" % handler.effect_id)

## Set the camera reference and pass it to all handlers
func set_camera(camera: Camera3D) -> void:
	player_camera = camera
	
	# Update all existing handlers
	for handler in effect_handlers.values():
		if handler is BaseVisualEffect:
			handler.player_camera = camera
	
	DebugLogger.debug(module_name, "Camera reference updated for all handlers")

## Invoke a visual effect with timing parameters
func invoke_effect(effect_id: String, startup: float = 0.5, duration: float = 2.0, wind_down: float = 0.5) -> void:
	if not effect_handlers.has(effect_id):
		DebugLogger.error(module_name, "Unknown effect ID: %s" % effect_id)
		return
	
	# Special handling for blink - always allow it
	if effect_id != "blink":
		# Check if we can run this effect
		if not allow_simultaneous and active_effects.size() > 0:
			DebugLogger.warning(module_name, "Cannot run %s - simultaneous effects disabled" % effect_id)
			return
		
		if max_simultaneous >= 0 and active_effects.size() >= max_simultaneous:
			DebugLogger.warning(module_name, "Cannot run %s - max simultaneous effects reached" % effect_id)
			return
	
	if effect_id in active_effects:
		DebugLogger.warning(module_name, "Effect %s already active" % effect_id)
		return
	
	# Get handler and invoke
	var handler = effect_handlers[effect_id] as BaseVisualEffect
	handler.invoke_effect(startup, duration, wind_down)

## Stop an effect immediately
func stop_effect(effect_id: String) -> void:
	if not effect_handlers.has(effect_id):
		DebugLogger.error(module_name, "Unknown effect ID: %s" % effect_id)
		return
	
	var handler = effect_handlers[effect_id] as BaseVisualEffect
	handler.stop_immediately()

## Stop all active effects
func stop_all_effects() -> void:
	DebugLogger.info(module_name, "Stopping all effects")
	
	for effect_id in active_effects.duplicate():
		stop_effect(effect_id)

## Check if an effect is currently active
func is_effect_active(effect_id: String) -> bool:
	return effect_id in active_effects

## Get list of active effects
func get_active_effects() -> Array[String]:
	return active_effects

## Called when an effect starts
func _on_effect_started(effect_id: String) -> void:
	active_effects.append(effect_id)
	DebugLogger.info(module_name, "Effect started: %s (active: %d)" % [effect_id, active_effects.size()])
	effect_started.emit(effect_id)

## Called when an effect finishes
func _on_effect_finished(effect_id: String) -> void:
	active_effects.erase(effect_id)
	DebugLogger.info(module_name, "Effect finished: %s (active: %d)" % [effect_id, active_effects.size()])
	effect_finished.emit(effect_id)
