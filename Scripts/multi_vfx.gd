# MultiVFXPlayer.gd
extends Node3D
class_name MultiVFX
## Enable debug logging for this module
@export var enable_debug: bool = false
var module_name: String = "MultiVFXPlayer"

## Auto-stop particles after this duration (0 = don't auto-stop)
@export var auto_stop_duration: float = 0.0

# Internal
var particle_systems: Array[GPUParticles3D] = []

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Collect all GPUParticles3D children
	_collect_particle_systems()
	
	# Make sure they start as not emitting
	for particles in particle_systems:
		particles.emitting = false
	
	DebugLogger.debug(module_name, "Found %d particle systems" % particle_systems.size())

func _collect_particle_systems() -> void:
	particle_systems.clear()
	
	for child in get_children():
		if child is GPUParticles3D:
			particle_systems.append(child)
			DebugLogger.debug(module_name, "Found particle system: %s" % child.name)

func emit() -> void:
	DebugLogger.debug(module_name, "Starting all particle emissions")
	
	for particles in particle_systems:
		particles.emitting = true
		particles.restart()
	
	# Auto-stop if configured
	if auto_stop_duration > 0.0:
		await get_tree().create_timer(auto_stop_duration).timeout
		stop()

func stop() -> void:
	DebugLogger.debug(module_name, "Stopping all particle emissions")
	
	for particles in particle_systems:
		particles.emitting = false
