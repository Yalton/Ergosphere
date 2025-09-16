# DeathCutsceneController.gd
extends Node3D

## Enable debug logging for this module
@export var enable_debug: bool = true
var module_name: String = "DeathCutscene"

## Reference to the intact station scene node (MiniStation)
@export var intact_station: Node3D

## Packed scene for the shattered station
@export var shattered_station_scene: PackedScene

## Camera that looks at the station
@export var death_camera: Camera3D

## Audio player for creaking sounds (plays during wait)
@export var creaking_audio: AudioStreamPlayer

## Audio player for power failure sound (breaking/shattering)
@export var power_failure_audio: AudioStreamPlayer

## Audio player for explosion sound
@export var explosion_audio: AudioStreamPlayer

## Reference to explosion VFX node (MultiVFXPlayer for engine explosion)
@export var explosion_vfx: Node3D

## Reference to power failure VFX node (MultiVFXPlayer for subtle effects)
@export var power_failure_vfx: Node3D

## Animation player for ending animation
@export var ending_animation_player: AnimationPlayer

## Time to wait before transitioning to main menu after animation starts
@export var transition_delay: float = 5.0

## Path to main menu scene
@export_file("*.tscn") var main_menu_path: String = "res://scenes/main_menu.tscn"

## Path to outro cutscene for ending death
@export_file("*.tscn") var outro_cutscene_path: String = "res://scenes/outro_cutscene.tscn"

# Internal state
var death_type: String = ""
var animation_started: bool = false
var shattered_instance: Node3D

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Make sure camera is current
	if death_camera:
		death_camera.current = true
	
	
	intact_station.visible = true
	
	# Check what type of death this is from GameManager or passed parameter
	_determine_death_type()
	
	# Wait for fade in to complete if TransitionManager exists
	if TransitionManager:
		await TransitionManager.fade_from_black()
		DebugLogger.debug(module_name, "Fade in complete, starting animation")
	
	# Start the appropriate animation
	_start_death_animation()

func _determine_death_type() -> void:
	# Check GameManager for which task killed the player
	if GameManager and GameManager.died_to != "":
		var failed_task = GameManager.died_to
		
		if failed_task == "restore_power":
			death_type = "power_failure"
		elif failed_task == "replace_heatsink":
			death_type = "engine_explosion"
		elif failed_task == "ending":
			death_type = "ending"
		else:
			# Default to power failure if unknown
			death_type = "power_failure"
			DebugLogger.warning(module_name, "Unknown failed task: %s, defaulting to power_failure" % failed_task)
	else:
		# Default if no GameManager or died_to not set
		death_type = "power_failure"
		DebugLogger.warning(module_name, "No death cause found, defaulting to power_failure")
	
	DebugLogger.info(module_name, "Death type determined: %s" % death_type)

func _start_death_animation() -> void:
	if animation_started:
		return
	
	animation_started = true
	DebugLogger.info(module_name, "Starting death animation for: %s" % death_type)
	
	# Start playing creaking sound immediately for power failure and ending
	if (death_type == "power_failure" or death_type == "ending") and creaking_audio:
		creaking_audio.play()
		DebugLogger.debug(module_name, "Started creaking sound")
	
	# Keep intact station visible for dramatic effect
	DebugLogger.info(module_name, "Showing intact station for 3 seconds...")
	await get_tree().create_timer(3.0).timeout
	
	# Start appropriate animation based on death type
	if death_type == "engine_explosion":
		_play_engine_explosion()
	elif death_type == "ending":
		_play_ending()
	else:
		_play_power_failure()

func _play_ending() -> void:
	DebugLogger.info(module_name, "Playing ending animation")
	
	# Continue creaking for another moment
	await get_tree().create_timer(2.0).timeout
	
	# Fade out creaking sound
	if creaking_audio and creaking_audio.playing:
		var tween = create_tween()
		tween.tween_property(creaking_audio, "volume_db", -40.0, 0.5)
		tween.tween_callback(creaking_audio.stop)
		DebugLogger.debug(module_name, "Fading out creaking sound")
	
	# Play ending animation if animation player exists
	if ending_animation_player:
		ending_animation_player.play("ending")
		DebugLogger.debug(module_name, "Playing ending animation")
	else:
		DebugLogger.error(module_name, "No ending animation player assigned!")
	
	# Start transition timer - goes to outro cutscene instead
	_start_transition_timer()

func _play_power_failure() -> void:
	DebugLogger.info(module_name, "Playing power failure animation")
	
	# Wait for dramatic effect while creaking continues
	await get_tree().create_timer(2.0).timeout
	
	# Fade out creaking sound
	if creaking_audio and creaking_audio.playing:
		var tween = create_tween()
		tween.tween_property(creaking_audio, "volume_db", -40.0, 0.5)
		tween.tween_callback(creaking_audio.stop)
		DebugLogger.debug(module_name, "Fading out creaking sound")
	
	# Trigger VFX, play sound, and spawn shattered station all at once
	if power_failure_vfx and power_failure_vfx.has_method("emit"):
		power_failure_vfx.emit()
		DebugLogger.debug(module_name, "Triggered power failure VFX")
	
	if power_failure_audio:
		power_failure_audio.play()
		DebugLogger.debug(module_name, "Playing power failure breaking sound")
	
	# Spawn and configure shattered station
	_spawn_shattered_station("power_failure")
	
	# Start transition timer
	_start_transition_timer()

func _play_engine_explosion() -> void:
	DebugLogger.info(module_name, "Playing engine explosion animation")
	
	# Play explosion sound
	if explosion_audio:
		explosion_audio.play()
		DebugLogger.debug(module_name, "Playing explosion sound")
	
	# Trigger explosion VFX
	if explosion_vfx and explosion_vfx.has_method("emit"):
		explosion_vfx.emit()
		DebugLogger.debug(module_name, "Triggered explosion VFX")
	
	# Small delay for explosion to register visually
	await get_tree().create_timer(0.2).timeout
	
	# Spawn and configure shattered station
	_spawn_shattered_station("engine_explosion")
	
	# Start transition timer
	_start_transition_timer()

func _spawn_shattered_station(shatter_type: String) -> void:
	if not shattered_station_scene:
		DebugLogger.error(module_name, "No shattered station scene assigned!")
		return
	
	# Hide intact station
	if intact_station:
		intact_station.visible = false
	
	# Instantiate shattered station
	shattered_instance = shattered_station_scene.instantiate()
	add_child(shattered_instance)
	
	# Position it where the intact station was
	if intact_station:
		shattered_instance.global_position = intact_station.global_position
		shattered_instance.global_rotation = intact_station.global_rotation
	
	# Tell the shattered station to explode with appropriate parameters
	if shattered_instance.has_method("explode"):
		shattered_instance.explode(shatter_type)
	else:
		DebugLogger.error(module_name, "Shattered station doesn't have explode() method!")
	
	DebugLogger.info(module_name, "Spawned shattered station with type: %s" % shatter_type)

func _start_transition_timer() -> void:
	DebugLogger.info(module_name, "Starting transition timer for %f seconds" % transition_delay)
	
	await get_tree().create_timer(transition_delay).timeout
	
	# Check death type to determine where to transition
	if death_type == "ending":
		_transition_to_outro_cutscene()
	else:
		_transition_to_main_menu()

func _transition_to_outro_cutscene() -> void:
	DebugLogger.info(module_name, "Transitioning to outro cutscene")
	
	# Restore gravity before leaving if we spawned a shattered station
	if shattered_instance and shattered_instance.has_method("restore_gravity"):
		shattered_instance.restore_gravity()
		DebugLogger.debug(module_name, "Restored gravity before transition")
	
	# Use TransitionManager if available
	if TransitionManager:
		await TransitionManager.fade_to_black()
		get_tree().change_scene_to_file(outro_cutscene_path)
		await TransitionManager.fade_from_black()
	else:
		# Direct scene change as fallback
		get_tree().change_scene_to_file(outro_cutscene_path)

func _transition_to_main_menu() -> void:
	DebugLogger.info(module_name, "Transitioning to main menu")
	
	# Restore gravity before leaving if we spawned a shattered station
	if shattered_instance and shattered_instance.has_method("restore_gravity"):
		shattered_instance.restore_gravity()
		DebugLogger.debug(module_name, "Restored gravity before transition")
	
	# Use TransitionManager if available
	if TransitionManager:
		await TransitionManager.fade_to_black()
		get_tree().change_scene_to_file(main_menu_path)
		await TransitionManager.fade_from_black()
	else:
		# Direct scene change as fallback
		get_tree().change_scene_to_file(main_menu_path)

# Public method to manually set death type before scene loads
func set_death_type(type: String) -> void:
	death_type = type
	DebugLogger.info(module_name, "Death type manually set to: %s" % type)
