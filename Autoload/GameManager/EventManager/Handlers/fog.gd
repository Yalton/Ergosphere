# fog.gd
extends EventHandler
class_name FogEvent

## Handles volumetric fog density events with smooth transitions

@export_group("Fog Settings")
## Target fog density when active
@export var target_fog_density: float = 0.1
## Base time to fade in (seconds) - will be randomized
@export var base_fade_in_time: float = 20.0
## Base time to hold fog (seconds) - will be randomized  
@export var base_hold_time: float = 30.0
## Base time to fade out (seconds) - will be randomized
@export var base_fade_out_time: float = 20.0
## Time variation percentage (0.0-1.0) for randomization
@export var time_variation: float = 0.3

# Internal state
var world_environment: WorldEnvironment
var original_fog_density: float = 0.0
var fog_tween: Tween
var is_fog_active: bool = false

func _ready() -> void:
	super._ready()
	module_name = "FogEvent"
	
	# Define which events this handler processes
	handled_event_ids = ["fog", "fog_event"]
	
	# Find world environment
	_find_world_environment()
	
	DebugLogger.debug(module_name, "FogEvent ready")

func _find_world_environment() -> void:
	## Find the WorldEnvironment node in the scene
	world_environment = get_tree().get_first_node_in_group("world_environment")
	if not world_environment:
		world_environment = _search_world_environment(get_tree().root)
	
	if world_environment and world_environment.environment:
		original_fog_density = world_environment.environment.volumetric_fog_density
		DebugLogger.debug(module_name, "Found WorldEnvironment, original fog density: %f" % original_fog_density)
	else:
		DebugLogger.warning(module_name, "WorldEnvironment not found!")

func _search_world_environment(node: Node) -> WorldEnvironment:
	## Recursively search for WorldEnvironment node
	if node is WorldEnvironment:
		return node
	
	for child in node.get_children():
		var result = _search_world_environment(child)
		if result:
			return result
	
	return null

func can_execute() -> bool:
	# First check base requirements
	if not super.can_execute():
		return false
	
	if is_fog_active:
		DebugLogger.warning(module_name, "Fog event already active")
		return false
	
	if not world_environment or not world_environment.environment:
		DebugLogger.error(module_name, "No WorldEnvironment found")
		return false
	
	return true

func execute() -> bool:
	# Call base implementation
	if not super.execute():
		return false
	
	DebugLogger.info(module_name, "Executing fog event")
	is_fog_active = true
	
	# Calculate randomized timings
	var fade_in_time = _randomize_time(base_fade_in_time)
	var hold_time = _randomize_time(base_hold_time)
	var fade_out_time = _randomize_time(base_fade_out_time)
	
	DebugLogger.debug(module_name, "Fog timing - In: %.1fs, Hold: %.1fs, Out: %.1fs" % [fade_in_time, hold_time, fade_out_time])
	
	# Start fog sequence
	_start_fog_sequence(fade_in_time, hold_time, fade_out_time)
	
	return true

func end() -> void:
	# Kill any active tween
	if fog_tween and fog_tween.is_valid():
		fog_tween.kill()
	
	# Reset fog density
	if world_environment and world_environment.environment:
		world_environment.environment.volumetric_fog_density = original_fog_density
	
	is_fog_active = false
	
	DebugLogger.info(module_name, "Fog event completed")
	
	# Call base implementation
	super.end()

func _randomize_time(base_time: float) -> float:
	## Apply random variation to timing
	var variation = base_time * time_variation
	return base_time + randf_range(-variation, variation)

func _start_fog_sequence(fade_in_time: float, hold_time: float, fade_out_time: float) -> void:
	## Execute the complete fog sequence
	if fog_tween and fog_tween.is_valid():
		fog_tween.kill()
	
	fog_tween = create_tween()
	
	# Fade in
	fog_tween.tween_method(_set_fog_density, original_fog_density, target_fog_density, fade_in_time)
	fog_tween.tween_callback(func(): DebugLogger.debug(module_name, "Fog fade-in complete"))
	
	# Hold
	fog_tween.tween_interval(hold_time)
	fog_tween.tween_callback(func(): DebugLogger.debug(module_name, "Fog hold complete, starting fade-out"))
	
	# Fade out
	fog_tween.tween_method(_set_fog_density, target_fog_density, original_fog_density, fade_out_time)
	fog_tween.tween_callback(_on_fog_sequence_complete)

func _set_fog_density(density: float) -> void:
	## Set the volumetric fog density
	if world_environment and world_environment.environment:
		world_environment.environment.volumetric_fog_density = density

func _on_fog_sequence_complete() -> void:
	## Called when the entire fog sequence is finished
	is_fog_active = false
	DebugLogger.debug(module_name, "Fog sequence complete, density reset to: %f" % original_fog_density)
	
	# End the event
	if is_active:
		end()
