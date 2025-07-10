# BaseVisualEffect.gd
extends Node
class_name BaseVisualEffect

signal effect_started
signal effect_finished

## Base class for all visual effects
var effect_id: String = ""
var effect_name: String = ""
var compositor_index: int = -1
var module_name: String = "BaseVisualEffect"
var player_camera : Camera3D

func _ready() -> void:
	DebugLogger.register_module(module_name, true)

## Play audio effect on the SFX bus
func play_effect_audio(audio_stream: AudioStream, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not audio_stream:
		DebugLogger.warning(module_name, "No audio stream provided")
		return
	
	Audio.play_sound(audio_stream, true, pitch_scale, volume_db, "SFX")
	DebugLogger.debug(module_name, "Playing effect audio: " + audio_stream.resource_path)

## Get the compositor effect at the specified index
func get_compositor_effect() -> CompositorEffect:
	# Implementation depends on your compositor setup
	# This is a placeholder
	return null

## Override these in derived classes
func startup_phase(time: float) -> void:
	pass

func duration_phase(time: float) -> void:
	pass

func wind_down_phase(time: float) -> void:
	pass

func _cleanup() -> void:
	pass
