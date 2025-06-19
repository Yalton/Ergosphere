extends BaseVisualEffect
class_name ChromaticAberrationHandler

## Chromatic aberration visual effect handler
## Uses compositor index 2 for the chromatic aberration post-process effect

@export_group("Chromatic Settings")
## Audio to play when effect starts
@export var aberration_sound: AudioStream
## Whether to pulse during duration (like heartbeat)
@export var enable_pulse: bool = false
## Pulse rate in BPM
@export var pulse_bpm: float = 80.0

var audio_player: AudioStreamPlayer
var compositor_effect: CompositorEffect
var pulse_tween: Tween

func _duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Chromatic aberration duration phase for %f seconds" % time)
	
	if not compositor_effect:
		return
	
	# Start pulse if enabled
	if enable_pulse and time > 0:
		_start_pulse()
	
	# Wait for duration
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Stop pulse
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null

func _wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Chromatic aberration wind down phase")
	
	if not compositor_effect:
		return
	
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Disable effect
	compositor_effect.enabled = false

func _cleanup() -> void:
	if compositor_effect:
		compositor_effect.enabled = false
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null

func _start_pulse() -> void:
	if not compositor_effect:
		return
	
	var beat_duration = 60.0 / pulse_bpm
	
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	
	# Pulse by toggling visibility to simulate heartbeat
	pulse_tween.tween_callback(func(): compositor_effect.enabled = true)
	pulse_tween.tween_interval(beat_duration * 0.4)
	pulse_tween.tween_callback(func(): compositor_effect.enabled = false)
	pulse_tween.tween_interval(beat_duration * 0.6)

func _ready() -> void:
	super._ready()
	effect_id = "chromatic_aberration"
	effect_name = "Chromatic Aberration"
	compositor_index = 2  # Chromatic is index 2
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)

func _startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Chromatic aberration startup phase")
	
	# Get compositor effect
	compositor_effect = get_compositor_effect()
	if not compositor_effect:
		DebugLogger.error(module_name, "No compositor effect found for chromatic aberration")
		return
	
	# Play sound
	if aberration_sound:
		audio_player.stream = aberration_sound
		audio_player.play()
	
	# Enable effect
	compositor_effect.enabled = true
	
	if time > 0:
		await get_tree().create_timer(time).timeout

func _extends BaseVisualEffect
class_name ChromaticAberrationHandler

## Chromatic aberration visual effect handler
## Uses shader index 2 for the chromatic aberration post-process effect

@export_group("Chromatic Settings")
## Audio to play when effect starts
@export var aberration_sound: AudioStream
## Whether to pulse during duration (like heartbeat)
@export var enable_pulse: bool = false
## Pulse rate in BPM
@export var pulse_bpm: float = 80.0

var audio_player: AudioStreamPlayer
var shader: PostProcessShader
var pulse_tween: Tween

func _ready() -> void:
	super._ready()
	effect_id = "chromatic_aberration"
	effect_name = "Chromatic Aberration"
	shader_index = 2  # Chromatic is index 2
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)

func _startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Chromatic aberration startup phase")
	
	# Get shader
	shader = get_shader()
	if not shader:
		DebugLogger.error(module_name, "No shader found for chromatic aberration")
		return
	
	# Play sound
	if aberration_sound:
		audio_player.stream = aberration_sound
		audio_player.play()
	
	# Enable shader with fade in
	shader.enabled = true
	
	# Could animate shader parameters here if the shader supports it
	if time > 0:
		await get_tree().create_timer(time).timeout

func _duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Chromatic aberration duration phase for %f seconds" % time)
	
	if not shader:
		return
	
	# Start pulse if enabled
	if enable_pulse and time > 0:
		_start_pulse()
	
	# Wait for duration
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Stop pulse
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null

func _wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Chromatic aberration wind down phase")
	
	if not shader:
		return
	
	# Could fade out shader parameters here
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Disable shader
	shader.enabled = false

func _cleanup() -> void:
	if shader:
		shader.enabled = false
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null

func _start_pulse() -> void:
	if not shader:
		return
	
	var beat_duration = 60.0 / pulse_bpm
	
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	
	# Pulse by modulating shader intensity if supported
	# For now, just toggle visibility to simulate pulse
	pulse_tween.tween_callback(func(): shader.enabled = true)
	pulse_tween.tween_interval(beat_duration * 0.4)
	pulse_tween.tween_callback(func(): shader.enabled = false)
	pulse_tween.tween_interval(beat_duration * 0.6)
