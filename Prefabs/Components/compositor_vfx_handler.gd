# CompositorVFXHandler.gd
extends BaseVisualEffect
class_name CompositorVFXHandler

## Unified handler for all compositor-based visual effects
## Manages multiple effects through a single handler to reduce code duplication

# Effect configuration dictionary
# Maps effect_id to compositor_index and optional settings
const EFFECT_CONFIG = {
	"glitch": {
		"index": 1,
		"name": "Glitch",
		"has_flicker": true
	},
	"chromatic_aberration": {
		"index": 2,
		"name": "Chromatic Aberration",
		"has_pulse": true
	},
	"edge_detection": {
		"index": 3,
		"name": "Edge Detection"
	},
	"geometric_fractal": {
		"index": 4,
		"name": "Geometric Fractal",
		"has_rotation": true
	},
	"purple_light": {
		"index": 5,
		"name": "Purple Light",
		"has_ambient": true
	},
	"hallucination_text": {
		"index": 6,
		"name": "Hallucination Text",
		"is_creepy": true
	},
	"shape_dilation": {
		"index": 7,
		"name": "Shape Dilation",
		"has_warp": true
	}
}

var compositor_effect: CompositorEffect
var current_effect_config: Dictionary = {}
var original_effect_id: String = ""
var current_effect_id: String = ""

func _ready() -> void:
	# Don't call super._ready() yet
	# We need to handle module naming differently
	module_name = "VFX_Compositor"
	DebugLogger.register_module(module_name, true)
	
	# Set a placeholder effect_id
	effect_id = "compositor_handler"
	effect_name = "Compositor Handler"
	
	DebugLogger.debug(module_name, "Compositor VFX handler ready")

## Set up for a specific effect before invoking
func setup_effect(p_effect_id: String) -> void:
	if not EFFECT_CONFIG.has(p_effect_id):
		DebugLogger.error(module_name, "Unknown effect ID: %s" % p_effect_id)
		return
	
	# Store the original for restoration later
	original_effect_id = effect_id
	current_effect_id = p_effect_id
	
	# Set the current effect details
	effect_id = p_effect_id
	# Create a copy of the config to avoid modifying the constant
	current_effect_config = EFFECT_CONFIG[p_effect_id].duplicate()
	effect_name = current_effect_config.name
	compositor_index = current_effect_config.index
	
	DebugLogger.debug(module_name, "Configured for effect: %s (index: %d)" % [effect_name, compositor_index])

## Override invoke_effect to handle our special case
func invoke_effect(startup: float = 0.5, duration: float = 2.0, wind_down: float = 0.5) -> void:
	# Make sure we have a valid effect configured
	if current_effect_config.is_empty() or effect_id == "compositor_handler":
		DebugLogger.error(module_name, "No effect configured - call setup_effect() first")
		return
	
	if is_active:
		DebugLogger.warning(module_name, "Effect %s is already active" % effect_id)
		return
	
	is_active = true
	effect_started.emit()
	
	DebugLogger.info(module_name, "Starting compositor effect: %s (%.1fs / %.1fs / %.1fs)" % [effect_id, startup, duration, wind_down])
	
	# Run the effect phases
	await _run_compositor_effect_phases(startup, duration, wind_down)
	
	is_active = false
	effect_finished.emit()
	
	DebugLogger.info(module_name, "Effect finished: %s" % effect_id)
	
	# Clear the configuration after use (not the constant, our copy)
	current_effect_config = {}
	effect_id = original_effect_id if original_effect_id else "compositor_handler"

## Custom phase runner for compositor effects
func _run_compositor_effect_phases(startup: float, duration: float, wind_down: float) -> void:
	# Startup phase
	if startup > 0:
		await startup_phase(startup)
	
	# Duration phase
	if duration > 0:
		await duration_phase(duration)
	
	# Wind down phase
	if wind_down > 0:
		await wind_down_phase(wind_down)
	
	# Cleanup
	_cleanup()

func startup_phase(time: float) -> void:
	if current_effect_config.is_empty():
		DebugLogger.error(module_name, "No effect configured")
		return
		
	DebugLogger.debug(module_name, "%s startup phase (%.1fs)" % [effect_name, time])
	
	# Get compositor effect
	compositor_effect = get_compositor_effect()
	if not compositor_effect:
		DebugLogger.error(module_name, "No compositor effect found at index %d" % compositor_index)
		return
	
	# Enable the compositor effect
	compositor_effect.enabled = true
	
	if time > 0:
		await get_tree().create_timer(time).timeout

func duration_phase(time: float) -> void:
	if not compositor_effect:
		return
		
	DebugLogger.debug(module_name, "%s duration phase (%.1fs)" % [effect_name, time])
	
	# Handle effect-specific behaviors during duration
	if time > 0:
		await get_tree().create_timer(time).timeout

func wind_down_phase(time: float) -> void:
	if not compositor_effect:
		return
		
	DebugLogger.debug(module_name, "%s wind down phase (%.1fs)" % [effect_name, time])
	
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Disable the compositor effect
	compositor_effect.enabled = false

func _cleanup() -> void:
	DebugLogger.debug(module_name, "Cleaning up %s effect" % effect_name)
	
	if compositor_effect:
		compositor_effect.enabled = false
		compositor_effect = null

func stop_immediately() -> void:
	if compositor_effect:
		compositor_effect.enabled = false
	
	# Call parent's stop but it won't interfere since we override invoke_effect
	is_active = false
	_cleanup()
	effect_finished.emit()
	
	# Reset effect_id (using empty dictionary, not clearing)
	current_effect_config = {}
	effect_id = original_effect_id if original_effect_id else "compositor_handler"
