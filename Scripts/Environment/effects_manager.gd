extends Node

## Manages visual and audio effects for station systems
## Add to "effects_manager" group in scene

signal power_state_changed(is_on: bool)

## Sound to play when power goes out
@export var power_off_sound: AudioStream
## Sound to play when power is restored  
@export var power_on_sound: AudioStream
## Color of emergency lighting during outage
@export var emergency_light_color: Color = Color(0.8, 0.0, 0.0)
## Brightness of emergency lighting
@export var emergency_light_energy: float = 0.3
## Shared emissive material resource for station surfaces
@export var shared_emissive_material: StandardMaterial3D
## Emergency emission energy level
@export var emergency_emission_energy: float = 0.3

var audio_player: AudioStreamPlayer
var original_light_states: Array = []
var original_emission_color: Color
var original_emission_energy: float
var power_is_on: bool = true

func _ready():
	add_to_group("effects_manager")
	
	# Register with debug logger
	DebugLogger.register_module("EffectsManager")
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)
	
	# Cache original emissive values
	if shared_emissive_material:
		original_emission_color = shared_emissive_material.emission
		original_emission_energy = shared_emissive_material.emission_energy_multiplier

## Brief flicker duration in seconds
@export var brief_flicker_duration: float = 0.15

## Triggers a brief flicker of all emissive lights
func trigger_brief_flicker() -> void:
	if not shared_emissive_material:
		DebugLogger.warning("EffectsManager", "No shared emissive material for flicker")
		return
	
	if not power_is_on:
		DebugLogger.debug("EffectsManager", "Power is off, skipping flicker")
		return
	
	DebugLogger.debug("EffectsManager", "Triggering brief flicker")
	
	var tween = create_tween()
	
	# Quick fade out
	tween.tween_property(shared_emissive_material, "emission_energy_multiplier", 
		0.0, brief_flicker_duration * 0.4)
	
	# Quick fade back in
	tween.tween_property(shared_emissive_material, "emission_energy_multiplier", 
		original_emission_energy, brief_flicker_duration * 0.6)


func update_power_lever(state:bool) -> void: 
		# Update power lever
	var lever = get_tree().get_first_node_in_group("power_lever")
	if lever and lever.has_method("set_power_state"):
		lever.set_power_state(state)

func kill_power(duration: float = 0.0) -> void:
	if not power_is_on:
		return
		
	power_is_on = false
	DebugLogger.log_message("EffectsManager", "Killing power for " + str(duration) + " seconds")
	
	# Update state
	if GameManager.state_manager:
		GameManager.state_manager.set_state(CommonUtils.STATE_POWER, "off")
		GameManager.state_manager.set_state(CommonUtils.STATE_EMERGENCY_MODE, true)
	
	# Play sound
	if power_off_sound and audio_player:
		audio_player.stream = power_off_sound
		audio_player.play()
	
	# Modify lights and materials
	_modify_lights(true)
	_modify_emissive_material(true)
	
	## Update power lever
	#var lever = get_tree().get_first_node_in_group("power_lever")
	#if lever and lever.has_method("set_power_state"):
		#lever.set_power_state(false)
	
	power_state_changed.emit(false)
	
	# Auto-restore if duration specified
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		restore_power()

func restore_power() -> void:
	if power_is_on:
		return
		
	power_is_on = true
	DebugLogger.log_message("EffectsManager", "Restoring power")
	
	# Update state
	if GameManager.state_manager:
		GameManager.state_manager.set_state(CommonUtils.STATE_POWER, "on")
		GameManager.state_manager.set_state(CommonUtils.STATE_EMERGENCY_MODE, false)
	
	# Play sound
	if power_on_sound and audio_player:
		audio_player.stream = power_on_sound
		audio_player.play()
	
	# Restore lights and materials
	_restore_lights()
	_modify_emissive_material(false)
	
	## Update power lever
	#var lever = get_tree().get_first_node_in_group("power_lever")
	#if lever and lever.has_method("set_power_state"):
		#lever.set_power_state(true)
	
	power_state_changed.emit(true)

func _modify_lights(emergency_mode: bool) -> void:
	if emergency_mode:
		original_light_states.clear()
	
	var lights = get_tree().get_nodes_in_group("lights")
	
	for light in lights:
		if light is Light3D:
			if emergency_mode:
				# Store original state
				original_light_states.append({
					"light": light,
					"color": light.light_color,
					"energy": light.light_energy,
					"enabled": light.visible
				})
				
				# Apply emergency lighting
				light.light_color = emergency_light_color
				light.light_energy = emergency_light_energy

func _restore_lights() -> void:
	for state in original_light_states:
		var light = state["light"]
		if is_instance_valid(light):
			light.light_color = state["color"]
			light.light_energy = state["energy"]
			light.visible = state["enabled"]
	
	original_light_states.clear()

func _modify_emissive_material(emergency_mode: bool) -> void:
	if not shared_emissive_material:
		return
	
	if emergency_mode:
		shared_emissive_material.emission = emergency_light_color
		shared_emissive_material.emission_energy_multiplier = emergency_emission_energy
	else:
		shared_emissive_material.emission = original_emission_color
		shared_emissive_material.emission_energy_multiplier = original_emission_energy
