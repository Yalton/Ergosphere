# engine_lube.gd
extends BaseSnappable
class_name EngineLube

signal lubrication_complete

@export_group("Components")
@export var animation_player: AnimationPlayer
@export var lube_mesh: Node3D
@export_group("Settings")
## Animation to play when lubrication starts
@export var lubrication_animation_name: String = "lubricate_engine"

func _ready() -> void:
	super._ready()
	module_name = "EngineLube"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Add to engine group for task system
	add_to_group("engine_lube")
	lube_mesh.visible = false
	DebugLogger.debug(module_name, "Engine lube initialized")

func _on_object_snapped(_object_name: String, _object_node: Node3D) -> void:
	# Only proceed if task is available
	if not task_aware_component or not task_aware_component.is_task_available:
		DebugLogger.debug(module_name, "Task not available")
		return
		
	DebugLogger.debug(module_name, "Lubrication started with: " + _object_name)
	_start_lubrication_sequence()

func _start_lubrication_sequence() -> void:
	# Play lubrication animation
	if animation_player and animation_player.has_animation(lubrication_animation_name):
		animation_player.play(lubrication_animation_name)
		
		# Wait for animation to finish
		if not animation_player.is_connected("animation_finished", _on_lubrication_animation_finished):
			animation_player.animation_finished.connect(_on_lubrication_animation_finished)
	else:
		# No animation, complete immediately
		_complete_lubrication()

func _on_lubrication_animation_finished(anim_name: String) -> void:
	if anim_name == lubrication_animation_name:
		_complete_lubrication()

func _complete_lubrication() -> void:
	# Complete the task
	if task_aware_component:
		task_aware_component.complete_task()
	
	# Emit signal
	lubrication_complete.emit()
	
	DebugLogger.info(module_name, "Engine lubrication completed")
