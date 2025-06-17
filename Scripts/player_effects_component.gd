extends Node
class_name PlayerEffectsComponent

## Component that handles visual effects by controlling shader parameters
## Expects a CanvasLayer with ColorRects that have shaders pre-configured

signal effect_started(effect_name: String)
signal effect_finished(effect_name: String)

## Canvas layer containing effect ColorRects
@export var effects_canvas_layer: CanvasLayer
## Path to the blink effect ColorRect node
@export var blink_rect_path: NodePath = "BlinkRect"
## Sound to play for blink effect (optional)
@export var blink_sound: AudioStream

## Reference to the blink ColorRect
var blink_rect: ColorRect
## Currently playing blink effect
var blink_active: bool = false
## Module name for debug logging
var module_name: String = "PlayerEffects"

func _ready() -> void:
	DebugLogger.register_module(module_name)
	
	if not effects_canvas_layer:
		DebugLogger.error(module_name, "No effects canvas layer assigned!")
		return
	
	# Get the blink rect
	if blink_rect_path:
		blink_rect = effects_canvas_layer.get_node(blink_rect_path) as ColorRect
		if blink_rect:
			DebugLogger.info(module_name, "Blink effect rect found")
		else:
			DebugLogger.error(module_name, "Could not find blink rect at path: %s" % blink_rect_path)

## Play a blink effect
func blink(fade_in: float = 0.1, hold: float = 0.05, fade_out: float = 0.15) -> void:
	if not blink_rect:
		DebugLogger.error(module_name, "No blink rect configured")
		return
	
	if blink_active:
		DebugLogger.warning(module_name, "Blink already active")
		return
	
	var material = blink_rect.material as ShaderMaterial
	if not material:
		DebugLogger.error(module_name, "Blink rect has no shader material")
		return
	
	blink_active = true
	effect_started.emit("blink")
	DebugLogger.info(module_name, "Blink: in=%f, hold=%f, out=%f" % [fade_in, hold, fade_out])
	
	# Play sound if configured
	if blink_sound and Audio:
		Audio.play_sound(blink_sound)
	
	# Animate the blink
	var tween = create_tween()
	tween.tween_method(_set_blink_progress.bind(material), 0.0, 1.0, fade_in)
	tween.tween_interval(hold)
	tween.tween_method(_set_blink_progress.bind(material), 1.0, 0.0, fade_out)
	
	await tween.finished
	
	blink_active = false
	effect_finished.emit("blink")

## Helper to set blink progress on shader
func _set_blink_progress(progress: float, material: ShaderMaterial) -> void:
	material.set_shader_parameter("blink_progress", progress)

## Check if blink is currently active
func is_blink_active() -> bool:
	return blink_active

## Stop blink immediately
func stop_blink() -> void:
	if not blink_active:
		return
	
	DebugLogger.info(module_name, "Stopping blink")
	
	# Kill any running tweens
	var tween = create_tween()
	tween.kill()
	
	# Reset shader
	if blink_rect and blink_rect.material:
		var material = blink_rect.material as ShaderMaterial
		material.set_shader_parameter("blink_progress", 0.0)
	
	blink_active = false
	effect_finished.emit("blink")
