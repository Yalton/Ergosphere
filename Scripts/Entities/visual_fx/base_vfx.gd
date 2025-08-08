# BaseVisualEffect.gd
extends Node
class_name BaseVisualEffect

signal effect_started
signal effect_finished

## Base class for all visual effects
## Effect identifier used to invoke this effect
@export var effect_id: String = ""
## Human-readable name for the effect
@export var effect_name: String = ""
## Compositor index for effects that use compositor (-1 for none)
@export var compositor_index: int = -1
## Whether to use a blink transition before/after the effect
@export var use_blink_transition: bool = false

var module_name: String = "BaseVisualEffect"
var player_camera: Camera3D
var is_active: bool = false

func _ready() -> void:
	
	# Set module name to the effect ID if available
	if not effect_id.is_empty():
		module_name = "VFX_" + effect_id

## Main entry point to invoke the effect
func invoke_effect(startup: float = 0.5, duration: float = 2.0, wind_down: float = 0.5) -> void:
	if is_active:
		DebugLogger.warning(module_name, "Effect %s is already active" % effect_id)
		return
	
	is_active = true
	effect_started.emit()
	
	DebugLogger.info(module_name, "Starting effect: %s (%.1fs / %.1fs / %.1fs)" % [effect_id, startup, duration, wind_down])
	
	# Run the effect phases
	await _run_effect_phases(startup, duration, wind_down)
	
	is_active = false
	effect_finished.emit()
	
	DebugLogger.info(module_name, "Effect finished: %s" % effect_id)

## Run through all effect phases
func _run_effect_phases(startup: float, duration: float, wind_down: float) -> void:
	# Optional blink before effect
	if use_blink_transition:
		await _blink_transition(0.1)
	
	# Startup phase
	if startup > 0:
		await startup_phase(startup)
	
	# Duration phase
	if duration > 0:
		await duration_phase(duration)
	
	# Wind down phase
	if wind_down > 0:
		await wind_down_phase(wind_down)
	
	# Optional blink after effect
	if use_blink_transition:
		await _blink_transition(0.1)
	
	# Cleanup
	_cleanup()

## Stop the effect immediately
func stop_immediately() -> void:
	if not is_active:
		return
	
	DebugLogger.info(module_name, "Stopping effect immediately: %s" % effect_id)
	
	is_active = false
	_cleanup()
	effect_finished.emit()

## Blink transition helper
func _blink_transition(blink_duration: float) -> void:
	# This could trigger a quick blink effect
	# For now, just a simple wait
	await get_tree().create_timer(blink_duration).timeout

## Play audio effect on the SFX bus
func play_effect_audio(audio_stream: AudioStream, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not audio_stream:
		DebugLogger.warning(module_name, "No audio stream provided")
		return
	
	# Using Audio singleton if available, otherwise create a player
	if has_node("/root/Audio"):
		get_node("/root/Audio").play_sound(audio_stream, true, pitch_scale, volume_db, "SFX")
	else:
		var audio_player = AudioStreamPlayer.new()
		add_child(audio_player)
		audio_player.stream = audio_stream
		audio_player.pitch_scale = pitch_scale
		audio_player.volume_db = volume_db
		audio_player.bus = "SFX"
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)
	
	DebugLogger.debug(module_name, "Playing effect audio: " + audio_stream.resource_path)

## Get the compositor effect at the specified index
func get_compositor_effect() -> CompositorEffect:
	if compositor_index < 0:
		DebugLogger.debug(module_name, "No compositor index set")
		return null
	
	if not player_camera:
		DebugLogger.warning(module_name, "No player camera reference")
		return null
	
	# Get the compositor from the camera
	var compositor = player_camera.compositor
	if not compositor:
		DebugLogger.warning(module_name, "Camera has no compositor")
		return null
	
	# Get the effect at the specified index
	if compositor_index >= compositor.compositor_effects.size():
		DebugLogger.error(module_name, "Compositor index %d out of range" % compositor_index)
		return null
	
	return compositor.compositor_effects[compositor_index]

## Override these in derived classes
func startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Default startup phase (%.1fs)" % time)
	if time > 0:
		await get_tree().create_timer(time).timeout

func duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Default duration phase (%.1fs)" % time)
	if time > 0:
		await get_tree().create_timer(time).timeout

func wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Default wind down phase (%.1fs)" % time)
	if time > 0:
		await get_tree().create_timer(time).timeout

func _cleanup() -> void:
	DebugLogger.debug(module_name, "Default cleanup")
	pass
