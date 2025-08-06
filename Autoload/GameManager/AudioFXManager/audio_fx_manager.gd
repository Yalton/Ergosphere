extends Node

## Manages dynamic audio effects for corruption and other temporary audio modifications
class_name AudioFXManager

var debug_logger: DebugLogger

## Dictionary to track active effects by bus name
var active_effects: Dictionary = {}

func _ready():
	DebugLogger.info("AudioFXManager", "AudioFXManager initialized")

## Applies a reverb effect to the specified audio bus
func apply_reverb(bus_name: String, room_size: float = 0.8, damping: float = 0.5, spread: float = 1.0, dry: float = 0.5) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		debug_logger.error("AudioFXManager", "Bus not found: " + bus_name)
		return
	
	var reverb = AudioEffectReverb.new()
	reverb.room_size = room_size
	reverb.damping = damping
	reverb.spread = spread
	reverb.dry = dry
	
	AudioServer.add_bus_effect(bus_idx, reverb)
	var effect_idx = AudioServer.get_bus_effect_count(bus_idx) - 1
	
	if not active_effects.has(bus_name):
		active_effects[bus_name] = []
	active_effects[bus_name].append({"type": "reverb", "index": effect_idx})
	
	debug_logger.info("AudioFXManager", "Applied reverb to bus: " + bus_name)

## Removes all effects from the specified audio bus
func remove_all_effects(bus_name: String) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		debug_logger.error("AudioFXManager", "Bus not found: " + bus_name)
		return
	
	if not active_effects.has(bus_name):
		debug_logger.warning("AudioFXManager", "No active effects on bus: " + bus_name)
		return
	
	# Remove effects in reverse order to maintain indices
	var effects = active_effects[bus_name]
	for i in range(effects.size() - 1, -1, -1):
		AudioServer.remove_bus_effect(bus_idx, effects[i].index)
	
	active_effects.erase(bus_name)
	debug_logger.info("AudioFXManager", "Removed all effects from bus: " + bus_name)

## Applies a distortion effect to the specified audio bus
func apply_distortion(bus_name: String, drive: float = 0.5, post_gain: float = 0.0) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		debug_logger.error("AudioFXManager", "Bus not found: " + bus_name)
		return
	
	var distortion = AudioEffectDistortion.new()
	distortion.mode = AudioEffectDistortion.MODE_CLIP
	distortion.drive = drive
	distortion.post_gain = post_gain
	
	AudioServer.add_bus_effect(bus_idx, distortion)
	var effect_idx = AudioServer.get_bus_effect_count(bus_idx) - 1
	
	if not active_effects.has(bus_name):
		active_effects[bus_name] = []
	active_effects[bus_name].append({"type": "distortion", "index": effect_idx})
	
	debug_logger.info("AudioFXManager", "Applied distortion to bus: " + bus_name)

## Temporarily applies an effect for a specified duration
func apply_temporary_effect(bus_name: String, effect_type: String, duration: float, params: Dictionary = {}) -> void:
	match effect_type:
		"reverb":
			apply_reverb(bus_name, params.get("room_size", 0.8), params.get("damping", 0.5), 
						params.get("spread", 1.0), params.get("dry", 0.5))
		"distortion":
			apply_distortion(bus_name, params.get("drive", 0.5), params.get("post_gain", 0.0))
		_:
			debug_logger.error("AudioFXManager", "Unknown effect type: " + effect_type)
			return
	
	await get_tree().create_timer(duration).timeout
	remove_all_effects(bus_name)
