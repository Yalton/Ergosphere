# ShutterWarningEventHandler.gd
extends EventHandler
class_name ShutterWarningEventHandler

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

var player: Player
var original_walk_speed: float
var original_crouch_speed: float
var particle_instance: Node3D
var is_warning_active: bool = false
var is_effect_active: bool = false
var window_lever: Node

func _ready() -> void:
	module_name = "ShutterWarningEvent"
	super._ready()
	
	# Define which events this handler processes
	handled_event_ids = ["shutter_warning"]
	
	DebugLogger.register_module(module_name, true)
	DebugLogger.debug(module_name, "ShutterWarningEventHandler ready")

func _on_execute(event_data: EventData, state_manager: StateManager) -> void:
	DebugLogger.info(module_name, "Executing shutter warning event")
	
	# Find the player
	player = CommonUtils.get_player()
	if not player:
		DebugLogger.error(module_name, "Could not find player")
		return
	
	# Find the window lever
	window_lever = get_tree().get_first_node_in_group("window_lever")
	if not window_lever:
		DebugLogger.error(module_name, "Could not find window lever")
		return
	
	# Connect to shutter state changes
	if window_lever.has_signal("shutters_toggled"):
		window_lever.shutters_toggled.connect(_on_shutters_toggled)
	
	# Show warning notification
	_show_warning()
	
	# Start warning timer using CommonUtils
	is_warning_active = true
	var warning_timer = CommonUtils.create_timer(self, warning_duration, true, true)
	warning_timer.timeout.connect(_on_warning_timeout)

func _show_warning() -> void:
	# Display warning message to player
	if player.ui_controller:
		player.ui_controller.show_message("WARNING", "Close the shutters immediately!")
	
	# Play warning sound using Audio singleton
	if warning_sound and Audio:
		Audio.play_sound(warning_sound)
	
	warning_started.emit()
	DebugLogger.info(module_name, "Warning displayed - player has %s seconds to close shutters" % warning_duration)

func _on_shutters_toggled(open_state: bool) -> void:
	if not is_warning_active or is_effect_active:
		return
	
	# Check if shutters are now closed
	if not open_state:
		DebugLogger.info(module_name, "Shutters closed - canceling warning")
		_cancel_warning()

func _on_warning_timeout() -> void:
	if not is_warning_active:
		return
		
	# Check the actual state of the shutters from the lever
	var shutters_open = true
	if window_lever and window_lever.shutters_open:
		shutters_open = window_lever.shutters_open
	
	if not shutters_open:
		DebugLogger.debug(module_name, "Warning timeout but shutters are closed")
		_cancel_warning()
		return
	
	DebugLogger.info(module_name, "Warning timeout - shutters still open, applying effects")
	_apply_effects()

func _apply_effects() -> void:
	is_warning_active = false
	is_effect_active = true
	
	# Store original speeds
	original_walk_speed = player.walk_speed
	original_crouch_speed = player.crouch_speed
	
	# Apply movement slow
	player.walk_speed *= movement_slow_factor
	player.crouch_speed *= movement_slow_factor
	
	# Spawn particle effect attached to player
	if particle_effect_scene:
		particle_instance = particle_effect_scene.instantiate()
		player.add_child(particle_instance)
		
		# Ensure particles are emitting
		if particle_instance.has_method("set_emitting"):
			particle_instance.set_emitting(true)
		
		DebugLogger.debug(module_name, "Spawned particle effect")
	
	# Apply vision warping effect
	_apply_vision_warp()
	
	# Play effect start sound using Audio singleton
	if effect_start_sound and Audio:
		Audio.play_sound(effect_start_sound)
	
	# Show effect message
	if player.ui_controller:
		player.ui_controller.show_message("AFFECTED", "You should have closed the shutters...")
	
	# Start effect timer using CommonUtils
	var effect_timer = CommonUtils.create_timer(self, effect_duration, true, true)
	effect_timer.timeout.connect(_on_effect_timeout)
	effects_started.emit()
	
	DebugLogger.info(module_name, "Effects applied for %s seconds" % effect_duration)

func _apply_vision_warp() -> void:
	# Try to find and use player's effects component for vision warping
	var effects_component = player.get_node_or_null("PlayerEffectsComponent")
	if effects_component and effects_component.has_method("apply_vision_warp"):
		effects_component.apply_vision_warp()
		DebugLogger.debug(module_name, "Applied vision warp via effects component")
	else:
		DebugLogger.warning(module_name, "No effects component found - vision warp not applied")

func _on_effect_timeout() -> void:
	if is_effect_active:
		_remove_effects()

func _remove_effects() -> void:
	is_effect_active = false
	
	# Restore movement speeds
	if player:
		player.walk_speed = original_walk_speed
		player.crouch_speed = original_crouch_speed
	
	# Remove particle effect
	if particle_instance:
		particle_instance.queue_free()
		particle_instance = null
	
	# Remove vision warp
	_remove_vision_warp()
	
	# Play effect end sound using Audio singleton
	if effect_end_sound and Audio:
		Audio.play_sound(effect_end_sound)
	
	effects_ended.emit()
	DebugLogger.info(module_name, "Effects removed")

func _remove_vision_warp() -> void:
	var effects_component = player.get_node_or_null("PlayerEffectsComponent") 
	if effects_component and effects_component.has_method("remove_vision_warp"):
		effects_component.remove_vision_warp()

func _cancel_warning() -> void:
	is_warning_active = false
	
	# Show success message
	if player.ui_controller:
		player.ui_controller.show_message("SAFE", "Good, the shutters are closed.")

func _on_complete(event_data: EventData, state_manager: StateManager) -> void:
	DebugLogger.info(module_name, "Completing shutter warning event")
	
	# Clean up any active effects
	if is_effect_active:
		_remove_effects()
	
	# Cancel warning if still active
	is_warning_active = false
	
	# Disconnect from lever
	if window_lever and window_lever.has_signal("shutters_toggled"):
		if window_lever.shutters_toggled.is_connected(_on_shutters_toggled):
			window_lever.shutters_toggled.disconnect(_on_shutters_toggled)
	
	is_warning_active = false
	is_effect_active = false
