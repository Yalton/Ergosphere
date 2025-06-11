extends BaseSnappable
class_name StationEngine

signal heatsink_failed
signal heatsink_fixed



@export_group("Components")
@export var heatsink_mesh: MeshInstance3D
@export var smoke_particles: GPUParticles3D
@export var animation_player: AnimationPlayer

@export_group("Settings")
@export var repair_animation_name: String = "heatsink_insert"

# Internal state
var is_operational: bool = true

func _ready() -> void:
	super._ready()
	
	# Register with debug logger
	module_name = "StationEngine"
	DebugLogger.register_module(module_name, enable_debug)
	
	
	# Add to engine_heatsinks group for event system to find us
	add_to_group("station_engine")
	
	# Set display name if not already set
	if display_name.is_empty():
		display_name = "StationEngine"
	
	# Initialize in operational state
	set_operational_state(true)
	
	DebugLogger.debug(module_name, "StationEngine initialized")

func set_operational_state(operational: bool) -> void:
	is_operational = operational
	can_snap = not operational  # Can only snap when broken
	
	if is_operational:
		# Show heatsink mesh
		if heatsink_mesh:
			heatsink_mesh.visible = true
		
		# Stop smoke particles
		if smoke_particles:
			smoke_particles.emitting = false
		
		DebugLogger.debug(module_name, "Set to operational state")
	else:
		# Hide heatsink mesh (it's broken/missing)
		if heatsink_mesh:
			heatsink_mesh.visible = false
		
		# Start smoke particles
		if smoke_particles:
			smoke_particles.emitting = true
		
		DebugLogger.debug(module_name, "Set to broken state - smoke leaking")

func trigger_failure() -> void:
	if not is_operational:
		DebugLogger.warning(module_name, "Heatsink already broken")
		return
	
	DebugLogger.info(module_name, "Heatsink failure triggered")
	set_operational_state(false)
	heatsink_failed.emit()

func _on_object_snapped(_object_name: String, _object_node: Node3D) -> void:
	if not is_operational:
		DebugLogger.debug(module_name, "Heatsink replacement started with: " + _object_name)
		_start_repair_sequence()

func _start_repair_sequence() -> void:
	# Play repair animation
	if animation_player and animation_player.has_animation(repair_animation_name):
		animation_player.play(repair_animation_name)
		
		# Wait for animation to finish
		if not animation_player.is_connected("animation_finished", _on_repair_animation_finished):
			animation_player.animation_finished.connect(_on_repair_animation_finished)
	else:
		# No animation, complete repair immediately
		_complete_repair()

func _on_repair_animation_finished(anim_name: String) -> void:
	if anim_name == repair_animation_name:
		_complete_repair()

func _complete_repair() -> void:
	# Set back to operational (this will stop smoke and show mesh)
	set_operational_state(true)
	
	# Inform event system
	heatsink_fixed.emit()
	if task_aware_component: 
		task_aware_component.complete_task()
		
	# Inform GameManager if available
	if GameManager and GameManager.state_manager:
		GameManager.state_manager.set_state("engine_heatsink_operational", true)
	
	DebugLogger.info(module_name, "Heatsink repair completed")

# Public method for event system to check if this heatsink can fail
func can_fail() -> bool:
	return is_operational
