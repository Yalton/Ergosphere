extends Node3D

@export var particles: GPUParticles3D
@export var audio_player: AudioStreamPlayer3D
@export var min_delay: float = 30.0
@export var max_delay: float = 120.0
@export var effect_duration: float = 5.0
@export var enable_debug: bool = false
@export var vfx_name: String = "Placeholder"
var module_name: String = "Ambient VFX"
var timer: Timer

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	if not particles:
		DebugLogger.error(module_name, "No GPUParticles3D assigned")
		return
		
	if not audio_player:
		DebugLogger.error(module_name, "No AudioStreamPlayer3D assigned")
		return
	
	# Use CommonUtils for timer creation
	timer = CommonUtils.create_timer(self, 1.0, true, false)
	timer.timeout.connect(_trigger_vfx_effect)
	

	# Start first timer
	start_random_timer()
	
	DebugLogger.debug(module_name, str(vfx_name) + "  effect initialized")

func start_random_timer() -> void:
	var delay = randf_range(min_delay, max_delay)
	DebugLogger.debug(module_name, "Next " + str(vfx_name) + " in " + str(delay) + " seconds")
	timer.wait_time = delay
	timer.start()

func _trigger_vfx_effect() -> void:
	DebugLogger.debug(module_name, "Triggering " + str(vfx_name) + " effect")
	
	# Start particles
	particles.emitting = true
	
	# Play audio
	audio_player.play()
	
	# Stop particles after duration using CommonUtils
	CommonUtils.create_one_shot_timer(self, effect_duration, func(): particles.emitting = false)
	
	# Start next random timer
	start_random_timer()
