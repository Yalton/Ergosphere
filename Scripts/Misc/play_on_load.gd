extends AnimationPlayer

@export var animation_name: String = "default"
## Maximum delay in seconds before playing animation. 0 = no delay, values > 0 create random delay from 0 to this value
@export var max_delay: float = 0.0
@export var enable_debug: bool = false
var module_name: String = "AnimPlayer"

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	if animation_name == "" or not has_animation(animation_name):
		DebugLogger.warning(module_name, "Animation not found: " + animation_name)
		return
	
	if max_delay > 0:
		var delay = randf() * max_delay
		DebugLogger.debug(module_name, "Will play animation '" + animation_name + "' after " + str(delay) + " seconds")
		
		var timer = get_tree().create_timer(delay)
		timer.timeout.connect(_play_animation)
	else:
		_play_animation()

func _play_animation() -> void:
	DebugLogger.debug(module_name, "Playing animation: " + animation_name)
	play(animation_name)
