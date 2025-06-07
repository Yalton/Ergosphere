# EmissiveFlickerManager.gd
extends Node

## The shared emissive material that all objects use
@export var shared_emissive_material: StandardMaterial3D
## Minimum time between flickers in seconds
@export var min_flicker_interval: float = 20.0
## Maximum time between flickers in seconds  
@export var max_flicker_interval: float = 60.0
## How long the flicker effect lasts
@export var flicker_duration: float = 0.3
## How much to reduce emission during flicker (0.0 = off, 1.0 = no change)
@export var flicker_intensity: float = 0.1

@export var enable_debug: bool = false
var module_name: String = "EmissiveFlicker"

var flicker_timer: Timer
var flicker_tween: Tween
var original_emission_energy: float
var is_power_on: bool = true
var is_flickering: bool = false

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	if not shared_emissive_material:
		DebugLogger.error(module_name, "No shared emissive material assigned!")
		return
	
	# Store original emission energy
	original_emission_energy = shared_emissive_material.emission_energy_multiplier
	
	# Create flicker timer
	flicker_timer = Timer.new()
	flicker_timer.one_shot = true
	flicker_timer.timeout.connect(_trigger_flicker)
	add_child(flicker_timer)
	
	# Connect to state manager to monitor power
	if GameManager and GameManager.state_manager:
		GameManager.state_manager.state_changed.connect(_on_state_changed)
		is_power_on = GameManager.state_manager.is_power_on()
	
	# Start first timer
	_start_random_timer()
	
	DebugLogger.debug(module_name, "Emissive flicker manager initialized")

func _start_random_timer() -> void:
	# Only start timer if power is on
	if not is_power_on:
		return
		
	var delay = randf_range(min_flicker_interval, max_flicker_interval)
	flicker_timer.start(delay)
	DebugLogger.debug(module_name, "Next flicker in " + str(delay) + " seconds")

func _trigger_flicker() -> void:
	if not is_power_on or is_flickering:
		return
		
	DebugLogger.debug(module_name, "Triggering emissive flicker")
	is_flickering = true
	
	# Kill existing tween if any
	if flicker_tween and flicker_tween.is_valid():
		flicker_tween.kill()
	
	# Create flicker effect
	flicker_tween = create_tween()
	
	# Quick dim down
	flicker_tween.tween_property(shared_emissive_material, "emission_energy_multiplier", 
		original_emission_energy * flicker_intensity, flicker_duration * 0.3)
	
	# Quick bright back up  
	flicker_tween.tween_property(shared_emissive_material, "emission_energy_multiplier", 
		original_emission_energy, flicker_duration * 0.2)
	
	# Another quick dim
	flicker_tween.tween_property(shared_emissive_material, "emission_energy_multiplier", 
		original_emission_energy * flicker_intensity, flicker_duration * 0.2)
	
	# Final restore
	flicker_tween.tween_property(shared_emissive_material, "emission_energy_multiplier", 
		original_emission_energy, flicker_duration * 0.3)
	
	flicker_tween.finished.connect(_on_flicker_complete)

func _on_flicker_complete() -> void:
	is_flickering = false
	
	# Start next random timer
	_start_random_timer()
	
	DebugLogger.debug(module_name, "Flicker complete")

func _on_state_changed(state_name: String, new_value: Variant) -> void:
	if state_name == "power":
		var was_power_on = is_power_on
		is_power_on = (new_value == "on")
		
		if is_power_on and not was_power_on:
			# Power restored, start timer again
			_start_random_timer()
			DebugLogger.debug(module_name, "Power restored, resuming flicker timer")
		elif not is_power_on and was_power_on:
			# Power lost, stop timer
			flicker_timer.stop()
			if is_flickering:
				# Stop any active flicker
				if flicker_tween and flicker_tween.is_valid():
					flicker_tween.kill()
				is_flickering = false
			DebugLogger.debug(module_name, "Power lost, stopping flicker timer")
