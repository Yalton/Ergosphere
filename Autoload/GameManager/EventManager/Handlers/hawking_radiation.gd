extends EventHandler
class_name HawkingRadiationEvent

## Event that warns player to close shutters or suffer vision/movement effects
## If shutters aren't closed within 15 seconds, player gets slowed, particles, and warped vision for 5 seconds

signal warning_started
signal effects_started
signal effects_ended

@export_group("Timing")
## Time in seconds player has to close shutters after warning
@export var warning_duration: float = 15.0
## Duration of the negative effects if player doesn't close shutters
@export var effect_duration: float = 5.0

@export_group("Effects")
## Movement speed multiplier when affected (0.5 = half speed)
@export var movement_slow_factor: float = 0.3
## Particle effect scene to instantiate when player is affected
@export var particle_effect_scene: PackedScene

@export_group("Audio")
## Sound to play when warning is issued
@export var warning_sound: AudioStream
## Sound to play when effects start
@export var effect_start_sound: AudioStream
## Sound to play when effects end  
@export var effect_end_sound: AudioStream

var player: Node3D
var original_walk_speed: float
var original_crouch_speed: float
var particle_instance: Node3D
var is_warning_active: bool = false
var is_effect_active: bool = false
var window_lever: Node
var warning_timer: Timer

func _ready() -> void:
	# Define which events this handler processes
	handled_event_ids = ["hawking_radiation", "shutter_warning"]

func _can_execute_internal() -> Dictionary:
	# Check if player exists
	player = CommonUtils.get_player()
	if not player:
		return {"success": false, "message": "No player found in scene"}
	
	# Check if window lever exists
	window_lever = get_tree().get_first_node_in_group("window_lever")
	if not window_lever:
		return {"success": false, "message": "No window lever found in scene"}
	
	# Check if player has required movement properties
	if not player.has_property("walk_speed") or not player.has_property("crouch_speed"):
		return {"success": false, "message": "Player missing required movement properties"}
	
	return {"success": true, "message": "OK"}

func _execute_internal() -> Dictionary:
	# Connect to shutter state changes
	if window_lever.has_signal("shutters_toggled"):
		window_lever.shutters_toggled.connect(_on_shutters_toggled)
	else:
		return {"success": false, "message": "Window lever missing shutters_toggled signal"}
	
	# Show warning notification
	_show_warning()
	
	# Start warning timer
	is_warning_active = true
	warning_timer = Timer.new()
	warning_timer.wait_time = warning_duration
	warning_timer.one_shot = true
	warning_timer.timeout.connect(_on_warning_timeout)
	add_child(warning_timer)
	warning_timer.start()
	
	return {"success": true, "message": "OK"}

func end() -> void:
	# Clean up any active effects
	if is_effect_active:
		_remove_effects()
	
	# Cancel warning if still active
	is_warning_active = false
	
	# Clean up timer
	if warning_timer:
		warning_timer.queue_free()
	
	# Disconnect from lever
	if window_lever and window_lever.has_signal("shutters_toggled"):
		if window_lever.shutters_toggled.is_connected(_on_shutters_toggled):
			window_lever.shutters_toggled.disconnect(_on_shutters_toggled)
	
	# Call base implementation
	super.end()

func _show_warning() -> void:
	# Display warning message to player
	CommonUtils.send_player_hint("", "WARNING: Close the shutters immediately!")
	
	# Play warning sound
	if warning_sound:
		play_audio(warning_sound)
	
	warning_started.emit()

func _on_shutters_toggled(open_state: bool) -> void:
	if not is_warning_active or is_effect_active:
		return
	
	# Check if shutters are now closed
	if not open_state:
		_cancel_warning()

func _on_warning_timeout() -> void:
	if not is_warning_active:
		return
		
	# Check the actual state of the shutters from the lever
	var shutters_open = true
	if window_lever and window_lever.has_property("shutters_open"):
		shutters_open = window_lever.shutters_open
	
	if not shutters_open:
		_cancel_warning()
		return
	
	_apply_effects()

func _apply_effects() -> void:
	is_warning_active = false
	is_effect_active = true
	
	# Store original speeds
	if player.has_property("walk_speed"):
		original_walk_speed = player.walk_speed
		player.walk_speed *= movement_slow_factor
	if player.has_property("crouch_speed"):
		original_crouch_speed = player.crouch_speed
		player.crouch_speed *= movement_slow_factor
	
	# Spawn particle effect attached to player
	if particle_effect_scene:
		particle_instance = particle_effect_scene.instantiate()
		player.add_child(particle_instance)
		
		# Ensure particles are emitting
		if particle_instance.has_method("set_emitting"):
			particle_instance.set_emitting(true)
	
	# Apply vision warping effect
	_apply_vision_warp()
	
	# Play effect start sound
	if effect_start_sound:
		play_audio(effect_start_sound)
	
	# Show effect message
	CommonUtils.send_player_hint("", "You should have closed the shutters...")
	
	# Start effect timer
	get_tree().create_timer(effect_duration).timeout.connect(_on_effect_timeout)
	effects_started.emit()

func _apply_vision_warp() -> void:
	# Try to find and use player's effects component for vision warping
	var effects_component = player.get_node_or_null("PlayerEffectsComponent")
	if effects_component and effects_component.has_method("apply_vision_warp"):
		effects_component.apply_vision_warp()

func _on_effect_timeout() -> void:
	if is_effect_active:
		_remove_effects()

func _remove_effects() -> void:
	is_effect_active = false
	
	# Restore movement speeds
	if player:
		if player.has_property("walk_speed"):
			player.walk_speed = original_walk_speed
		if player.has_property("crouch_speed"):
			player.crouch_speed = original_crouch_speed
	
	# Remove particle effect
	if particle_instance:
		particle_instance.queue_free()
		particle_instance = null
	
	# Remove vision warp
	_remove_vision_warp()
	
	# Play effect end sound
	if effect_end_sound:
		play_audio(effect_end_sound)
	
	effects_ended.emit()
	
	# End the event
	if is_active:
		end()

func _remove_vision_warp() -> void:
	var effects_component = player.get_node_or_null("PlayerEffectsComponent") 
	if effects_component and effects_component.has_method("remove_vision_warp"):
		effects_component.remove_vision_warp()

func _cancel_warning() -> void:
	is_warning_active = false
	
	# Show success message
	CommonUtils.send_player_hint("", "Good, the shutters are closed.")
	
	# End the event since player successfully closed shutters
	if is_active:
		end()
