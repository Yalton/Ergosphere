extends BaseVisualEffect
class_name CameraWobbleEffect

## Camera wobble/shake effect for horror moments

@export_group("Wobble Settings")
## Maximum rotation offset in degrees
@export var max_rotation: float = 2.0
## Maximum position offset in units
@export var max_position: float = 0.05
## Wobble frequency (oscillations per second)
@export var wobble_frequency: float = 15.0
## Whether to reduce intensity over time
@export var fade_over_time: bool = true

## Audio to play during wobble (optional)
@export var wobble_sound: AudioStream

var original_position: Vector3
var original_rotation: Vector3
var head_node: Node3D
var time_elapsed: float = 0.0
var total_duration: float = 0.0
var is_wobbling: bool = false

func _ready() -> void:
	super._ready()
	effect_id = "camera_wobble"
	effect_name = "Camera Wobble"
	module_name = "CameraWobbleEffect"
	DebugLogger.register_module(module_name)

func startup_phase(time: float) -> void:
	DebugLogger.log_message(module_name, "Starting camera wobble (%.1fs startup)" % time)
	
	# Find the head node from the player
	var player = CommonUtils.get_player()
	if not player:
		DebugLogger.warning(module_name, "No player found for camera wobble")
		return
	
	head_node = player.get_node_or_null("Head")
	if not head_node:
		DebugLogger.warning(module_name, "No Head node found on player")
		return
	
	# Store original transform
	original_position = head_node.position
	original_rotation = head_node.rotation
	
	# Play wobble sound if provided
	if wobble_sound:
		play_effect_audio(wobble_sound, 1.0, -5.0)
	
	# Start with subtle wobble that ramps up
	time_elapsed = 0.0
	is_wobbling = true
	var ramp_tween = create_tween()
	ramp_tween.tween_property(self, "time_elapsed", time, time)
	await ramp_tween.finished

func duration_phase(time: float) -> void:
	DebugLogger.log_message(module_name, "Camera wobble main phase (%.1fs)" % time)
	
	if not head_node:
		await get_tree().create_timer(time).timeout
		return
	
	total_duration = time
	time_elapsed = 0.0
	
	# Create a timer for the duration
	var timer = 0.0
	while timer < time and is_wobbling:
		timer += get_process_delta_time()
		time_elapsed = timer
		
		# Calculate intensity (fade if enabled)
		var intensity = 1.0
		if fade_over_time:
			intensity = 1.0 - (timer / time)
		
		# Apply wobble
		_apply_wobble(timer, intensity)
		
		await get_tree().process_frame
	
	# Reset to original transform
	if head_node:
		head_node.position = original_position
		head_node.rotation = original_rotation

func wind_down_phase(time: float) -> void:
	DebugLogger.log_message(module_name, "Camera wobble wind down (%.1fs)" % time)
	
	if not head_node:
		await get_tree().create_timer(time).timeout
		return
	
	# Gradually reduce wobble intensity
	var timer = 0.0
	while timer < time and is_wobbling:
		timer += get_process_delta_time()
		
		var intensity = 1.0 - (timer / time)
		_apply_wobble(time_elapsed + timer, intensity)
		
		await get_tree().process_frame
	
	# Ensure we return to original transform
	if head_node:
		head_node.position = original_position
		head_node.rotation = original_rotation

func _apply_wobble(time: float, intensity: float) -> void:
	if not head_node:
		return
	
	# Calculate wobble offsets using sine waves at different frequencies
	var rot_x = sin(time * wobble_frequency) * deg_to_rad(max_rotation) * intensity
	var rot_y = cos(time * wobble_frequency * 1.3) * deg_to_rad(max_rotation) * intensity
	var rot_z = sin(time * wobble_frequency * 0.7) * deg_to_rad(max_rotation * 0.5) * intensity
	
	var pos_x = cos(time * wobble_frequency * 1.1) * max_position * intensity
	var pos_y = sin(time * wobble_frequency * 0.9) * max_position * intensity
	var pos_z = cos(time * wobble_frequency * 1.2) * max_position * 0.5 * intensity
	
	# Apply the wobble
	head_node.rotation = original_rotation + Vector3(rot_x, rot_y, rot_z)
	head_node.position = original_position + Vector3(pos_x, pos_y, pos_z)

func _cleanup() -> void:
	DebugLogger.log_message(module_name, "Cleaning up camera wobble")
	is_wobbling = false
	
	# Reset to original transform
	if head_node:
		head_node.position = original_position
		head_node.rotation = original_rotation
		head_node = null

func stop_immediately() -> void:
	is_wobbling = false
	super.stop_immediately()
