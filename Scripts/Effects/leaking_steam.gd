extends Node3D

@export var particles: GPUParticles3D
@export var audio_player: AudioStreamPlayer3D
@export var min_delay: float = 30.0
@export var max_delay: float = 120.0
@export var effect_duration: float = 5.0
@export var enable_debug: bool = false

var module_name: String = "SteamLeak"
var timer: Timer

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	if not particles:
		DebugLogger.error(module_name, "No GPUParticles3D assigned")
		return
		
	if not audio_player:
		DebugLogger.error(module_name, "No AudioStreamPlayer3D assigned")
		return
	
	# Create timer
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_trigger_steam_leak)
	add_child(timer)
	
	# Start first timer
	start_random_timer()
	
	DebugLogger.debug(module_name, "Steam leak effect initialized")

func start_random_timer() -> void:
	var delay = randf_range(min_delay, max_delay)
	DebugLogger.debug(module_name, "Next steam leak in " + str(delay) + " seconds")
	timer.start(delay)

func _trigger_steam_leak() -> void:
	DebugLogger.debug(module_name, "Triggering steam leak effect")
	
	# Start particles
	particles.emitting = true
	
	# Play audio
	audio_player.play()
	
	# Stop particles after duration
	var stop_timer = get_tree().create_timer(effect_duration)
	stop_timer.timeout.connect(func(): particles.emitting = false)
	
	# Start next random timer
	start_random_timer()
