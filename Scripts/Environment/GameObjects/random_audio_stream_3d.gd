extends AudioStreamPlayer3D
@export var min_delay: float = 10.0
@export var max_delay: float = 50.0
@export var enable_debug: bool = false

var module_name: String = "PausableRandomAudio"
var timer: Timer
var is_paused: bool = false

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Check if we have a parent that's an AudioStreamRandomizer
	if not stream or not (stream is AudioStreamRandomizer):
		DebugLogger.error(module_name, "No AudioStreamRandomizer found")
		return
	
	# Create a timer for the delay
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	
	# Start the first timer
	start_random_timer()
	
	DebugLogger.debug(module_name, "PausableRandomAudio initialized")

func start_random_timer() -> void:
	if is_paused:
		return
		
	# Generate a random delay between min and max
	var delay = randf_range(min_delay, max_delay)
	DebugLogger.debug(module_name, "Setting timer for " + str(delay) + " seconds")
	timer.start(delay)

func _on_timer_timeout() -> void:
	if is_paused:
		return
		
	# Play the sound (randomizer will automatically pick a random stream)
	DebugLogger.debug(module_name, "Timer expired, playing random sound")
	play()
	
	# Start a new timer for the next sound
	start_random_timer()

func pause_audio() -> void:
	is_paused = true
	timer.stop()
	stop()  # Stop current playback if any
	DebugLogger.debug(module_name, "Audio paused")

func resume_audio() -> void:
	is_paused = false
	start_random_timer()
	DebugLogger.debug(module_name, "Audio resumed")
