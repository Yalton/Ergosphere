extends EventHandler
class_name MajorEventHandler

## Handles all major station events: hawking radiation, power outages, oxygen failures, and heatsink failures

# ============== HAWKING RADIATION SETTINGS ==============
@export_group("Hawking Radiation Settings")
## Time in seconds player has to close shutters after warning
@export var warning_duration: float = 15.0
## Duration of the negative effects if player doesn't close shutters
@export var effect_duration: float = 5.0
## Movement speed multiplier when affected (0.5 = half speed)
@export var movement_slow_factor: float = 0.3
## Particle effect scene to instantiate when player is affected
@export var particle_effect_scene: PackedScene

@export_group("Hawking Radiation Audio")
## Sound to play when warning is issued
@export var hawking_warning_sound: AudioStream
## Sound to play when effects start
@export var effect_start_sound: AudioStream
## Sound to play when effects end  
@export var effect_end_sound: AudioStream

# ============== POWER OUTAGE SETTINGS ==============
@export_group("Power Outage Settings")
## Sound to play when power fails
@export var power_failure_sound: AudioStream
## Sound to play when power is restored  
@export var power_restore_sound: AudioStream

# ============== OXYGEN FAILURE SETTINGS ==============
@export_group("Oxygen Failure Settings")
## Sound to play when oxygen system fails
@export var oxygen_failure_sound: AudioStream
## Sound to play when oxygen is restored
@export var oxygen_restore_sound: AudioStream

# ============== HEATSINK FAILURE SETTINGS ==============
@export_group("Heatsink Failure Settings")
## Sound to play when heatsink fails
@export var heatsink_failure_sound: AudioStream

# Signals for hawking radiation
signal warning_started
signal effects_started
signal effects_ended

# State tracking for hawking radiation
var player: Node3D
var original_walk_speed: float
var original_crouch_speed: float
var particle_instance: Node3D
var is_warning_active: bool = false
var is_effect_active: bool = false
var window_lever: Node
var warning_timer: Timer

# State tracking for heatsink failure
var failed_heatsink: StationEngine = null

func _ready() -> void:
	# All events this consolidated handler processes
	handled_event_ids = [
		"hawking_radiation", "shutter_warning",
		"power_outage",
		"oxygen_failure",
		"heatsink_failure"
	]
	
	DebugLogger.register_module("MajorEventHandler")

func _can_execute_internal() -> Dictionary:
	DebugLogger.log_message("MajorEventHandler", "Checking if can execute: " + event_data.id)
	
	match event_data.id:
		"hawking_radiation", "shutter_warning":
			return _can_execute_hawking()
		"power_outage":
			return _can_execute_power_outage()
		"oxygen_failure":
			return _can_execute_oxygen_failure()
		"heatsink_failure":
			return _can_execute_heatsink_failure()
		_:
			return {"success": false, "message": "Unknown event ID: " + event_data.id}

func _execute_internal() -> Dictionary:
	DebugLogger.log_message("MajorEventHandler", "Executing event: " + event_data.id)
	
	match event_data.id:
		"hawking_radiation", "shutter_warning":
			return _execute_hawking()
		"power_outage":
			return _execute_power_outage()
		"oxygen_failure":
			return _execute_oxygen_failure()
		"heatsink_failure":
			return _execute_heatsink_failure()
		_:
			return {"success": false, "message": "Unknown event ID: " + event_data.id}

func end() -> void:
	DebugLogger.log_message("MajorEventHandler", "Ending event: " + event_data.id)
	
	# Clean up based on event type
	match event_data.id:
		"hawking_radiation", "shutter_warning":
			_end_hawking()
		"power_outage":
			_end_power_outage()
		"oxygen_failure":
			_end_oxygen_failure()
		"heatsink_failure":
			_end_heatsink_failure()
		_:
			pass
	
	# Call base implementation
	super.end()

# ============== HAWKING RADIATION FUNCTIONS ==============
func _can_execute_hawking() -> Dictionary:
	player = CommonUtils.get_player()
	if not player:
		return {"success": false, "message": "No player found in scene"}
	
	window_lever = get_tree().get_first_node_in_group("window_lever")
	if not window_lever:
		return {"success": false, "message": "No window lever found in scene"}
	
	if not player.walk_speed or not player.crouch_speed:
		return {"success": false, "message": "Player missing required movement properties"}
	
	return {"success": true, "message": "OK"}

func _execute_hawking() -> Dictionary:
	if window_lever.has_signal("shutters_toggled"):
		window_lever.shutters_toggled.connect(_on_shutters_toggled)
	else:
		return {"success": false, "message": "Window lever missing shutters_toggled signal"}
	
	_show_hawking_warning()
	
	is_warning_active = true
	warning_timer = Timer.new()
	warning_timer.wait_time = warning_duration
	warning_timer.one_shot = true
	warning_timer.timeout.connect(_on_warning_timeout)
	add_child(warning_timer)
	warning_timer.start()
	
	return {"success": true, "message": "OK"}

func _show_hawking_warning() -> void:
	CommonUtils.send_player_hint("", "WARNING: Close the shutters immediately!")
	
	if hawking_warning_sound:
		play_audio(hawking_warning_sound)
	
	warning_started.emit()

func _on_shutters_toggled(open_state: bool) -> void:
	if not is_warning_active or is_effect_active:
		return
	
	if not open_state:
		_cancel_warning()

func _on_warning_timeout() -> void:
	if not is_warning_active:
		return
		
	var shutters_open = true
	if window_lever and window_lever.shutters_open:
		shutters_open = window_lever.shutters_open
	
	if not shutters_open:
		_cancel_warning()
		return
	
	_apply_hawking_effects()

func _apply_hawking_effects() -> void:
	is_warning_active = false
	is_effect_active = true
	
	original_walk_speed = player.walk_speed
	player.walk_speed *= movement_slow_factor
	original_crouch_speed = player.crouch_speed
	player.crouch_speed *= movement_slow_factor
	
	if particle_effect_scene:
		particle_instance = particle_effect_scene.instantiate()
		player.add_child(particle_instance)
		
		if particle_instance.has_method("set_emitting"):
			particle_instance.set_emitting(true)
	
	_apply_vision_warp()
	
	if effect_start_sound:
		play_audio(effect_start_sound)
	
	CommonUtils.send_player_hint("", "You should have closed the shutters...")
	
	get_tree().create_timer(effect_duration).timeout.connect(_on_effect_timeout)
	effects_started.emit()

func _apply_vision_warp() -> void:
	var effects_component = player.get_node_or_null("PlayerEffectsComponent")
	if effects_component and effects_component.has_method("apply_vision_warp"):
		effects_component.apply_vision_warp()

func _on_effect_timeout() -> void:
	if is_effect_active:
		_remove_hawking_effects()

func _remove_hawking_effects() -> void:
	is_effect_active = false
	
	if player:
		player.walk_speed = original_walk_speed
		player.crouch_speed = original_crouch_speed
	
	if particle_instance:
		particle_instance.queue_free()
		particle_instance = null
	
	_remove_vision_warp()
	
	if effect_end_sound:
		play_audio(effect_end_sound)
	
	effects_ended.emit()
	
	if is_active:
		end()

func _remove_vision_warp() -> void:
	var effects_component = player.get_node_or_null("PlayerEffectsComponent") 
	if effects_component and effects_component.has_method("remove_vision_warp"):
		effects_component.remove_vision_warp()

func _cancel_warning() -> void:
	is_warning_active = false
	
	CommonUtils.send_player_hint("", "Good, the shutters are closed.")
	
	if is_active:
		end()

func _end_hawking() -> void:
	if is_effect_active:
		_remove_hawking_effects()
	
	is_warning_active = false
	
	if warning_timer:
		warning_timer.queue_free()
	
	if window_lever and window_lever.has_signal("shutters_toggled"):
		if window_lever.shutters_toggled.is_connected(_on_shutters_toggled):
			window_lever.shutters_toggled.disconnect(_on_shutters_toggled)

# ============== POWER OUTAGE FUNCTIONS ==============
func _can_execute_power_outage() -> Dictionary:
	if not check_state("power", "on"):
		return {"success": false, "message": "Power is already off"}
	
	return {"success": true, "message": "OK"}

func _execute_power_outage() -> Dictionary:
	set_state("power", "off")
	
	notify_group("powered_objects", "on_power_lost")
	
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if effects_manager:
		effects_manager.kill_power()
		effects_manager.update_power_lever(false)
	else:
		return {"success": false, "message": "Could not find effects manager for power control"}
		
	trigger_emergency_task("restore_power")
	
	CommonUtils.send_player_hint("", "WARNING: Station Power Failure")
	
	return {"success": true, "message": "OK"}

func _end_power_outage() -> void:
	set_state("power", "on")
	
	notify_group("powered_objects", "on_power_restored")
	
	if power_restore_sound:
		play_audio(power_restore_sound)
		var effects_manager = get_tree().get_first_node_in_group("effects_manager")
		if effects_manager:
			effects_manager.update_power_lever(true)

# ============== OXYGEN FAILURE FUNCTIONS ==============
func _can_execute_oxygen_failure() -> Dictionary:
	if not check_state("oxygen_system", "operational"):
		return {"success": false, "message": "Oxygen system already failed"}
	
	return {"success": true, "message": "OK"}

func _execute_oxygen_failure() -> Dictionary:
	set_state("oxygen_system", "failed")
	
	notify_group("oxygen_dependent", "on_oxygen_lost")
	
	if oxygen_failure_sound:
		play_audio(oxygen_failure_sound)
	
	trigger_emergency_task("oxygen_filter_failure")
	
	CommonUtils.send_player_hint("", "WARNING: Oxygen System Failure")
	
	return {"success": true, "message": "OK"}

func _end_oxygen_failure() -> void:
	set_state("oxygen_system", "operational")
	
	notify_group("oxygen_dependent", "on_oxygen_restored")
	
	if oxygen_restore_sound:
		play_audio(oxygen_restore_sound)

# ============== HEATSINK FAILURE FUNCTIONS ==============
func _can_execute_heatsink_failure() -> Dictionary:
	if not check_state("engine_heatsink_operational", true):
		return {"success": false, "message": "Engine heatsink already failed"}
	
	var engines = get_tree().get_nodes_in_group("station_engine")
	var operational_count = 0
	
	for engine in engines:
		if engine is StationEngine and engine.can_fail():
			operational_count += 1
	
	if operational_count == 0:
		return {"success": false, "message": "No operational engines available to fail"}
	
	return {"success": true, "message": "OK"}

func _execute_heatsink_failure() -> Dictionary:
	set_state("engine_heatsink_operational", false)
	
	var engines = get_tree().get_nodes_in_group("station_engine")
	var operational_engines: Array[StationEngine] = []
	
	for engine in engines:
		if engine is StationEngine and engine.can_fail():
			operational_engines.append(engine)
	
	if operational_engines.is_empty():
		set_state("engine_heatsink_operational", true)
		return {"success": false, "message": "No operational engines found during execution"}
	
	failed_heatsink = operational_engines[randi() % operational_engines.size()]
	
	if not failed_heatsink.is_connected("heatsink_fixed", _on_heatsink_fixed):
		failed_heatsink.heatsink_fixed.connect(_on_heatsink_fixed)
	
	failed_heatsink.trigger_failure()
	
	if heatsink_failure_sound:
		play_audio(heatsink_failure_sound)
	
	trigger_emergency_task("replace_heatsink")
	
	CommonUtils.send_player_hint("", "WARNING: Engine Heatsink Failure")
	
	return {"success": true, "message": "OK"}

func _end_heatsink_failure() -> void:
	if failed_heatsink and failed_heatsink.is_connected("heatsink_fixed", _on_heatsink_fixed):
		failed_heatsink.heatsink_fixed.disconnect(_on_heatsink_fixed)
	
	failed_heatsink = null
	
	set_state("engine_heatsink_operational", true)

func _on_heatsink_fixed() -> void:
	if GameManager and GameManager.event_manager:
		GameManager.event_manager.end_event("heatsink_failure")
