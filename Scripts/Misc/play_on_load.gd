extends AnimationPlayer

@export var animation_name: String = "default"
@export var enable_debug: bool = false
var module_name: String = "AnimPlayer"

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	if animation_name != "" and has_animation(animation_name):
		DebugLogger.debug(module_name, "Playing animation: " + animation_name)
		play(animation_name)
	else:
		DebugLogger.warning(module_name, "Animation not found: " + animation_name)
