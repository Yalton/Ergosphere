# PlayerFlashlightComponent.gd
class_name PlayerFlashlightComponent
extends Node

## The spotlight node that acts as the flashlight
@export var flashlight_spot: SpotLight3D
## Sound played when turning flashlight on/off
@export var flashlight_click_sound: AudioStream
## Maximum battery duration in seconds
@export var flashlight_max_battery: float = 5.0
## Rate at which battery drains per second (1.0 = full drain rate)
@export var flashlight_drain_rate: float = 1.0
## Rate at which battery recharges per second (0.5 = half of drain rate)
@export var flashlight_recharge_rate: float = 0.5
## Delay before recharging starts after full depletion
@export var flashlight_recharge_delay: float = 1.0

# State
var flashlight_on: bool = false
var flashlight_battery: float = 5.0
var flashlight_depleted: bool = false
var flashlight_recharge_timer: float = 0.0
var flashlight_audio: AudioStreamPlayer3D

# References
var ui_controller: PlayerUI
var module_name: String = "PlayerFlashlightComponent"

signal battery_updated(percentage: float, show_meter: bool)

func _ready() -> void:
	DebugLogger.register_module(module_name, false)
	
	# Setup audio
	flashlight_audio = AudioStreamPlayer3D.new()
	flashlight_audio.name = "FlashlightAudio"
	flashlight_audio.bus = "SFX"
	add_child(flashlight_audio)
	
	# Initialize state
	if flashlight_spot:
		flashlight_spot.visible = false
	flashlight_battery = flashlight_max_battery

func set_ui_controller(controller: PlayerUI) -> void:
	ui_controller = controller

func toggle() -> void:
	if not flashlight_spot:
		DebugLogger.warning(module_name, "No flashlight SpotLight3D assigned")
		return
	
	# Can't toggle if depleted and not fully recharged
	if flashlight_depleted and flashlight_battery < flashlight_max_battery:
		DebugLogger.debug(module_name, "Flashlight depleted, must wait for full recharge")
		return
	
	flashlight_on = !flashlight_on
	flashlight_spot.visible = flashlight_on
	
	# Play click sound
	if flashlight_click_sound and flashlight_audio:
		flashlight_audio.stream = flashlight_click_sound
		flashlight_audio.play()
	
	# Reset depleted state if turning on with full battery
	if flashlight_on and flashlight_battery >= flashlight_max_battery:
		flashlight_depleted = false
	
	DebugLogger.debug(module_name, "Flashlight " + ("on" if flashlight_on else "off") + " - Battery: %.1f/%.1f" % [flashlight_battery, flashlight_max_battery])

func process_battery(delta: float) -> void:
	# Handle recharge delay after depletion
	if flashlight_depleted and flashlight_recharge_timer > 0:
		flashlight_recharge_timer -= delta
		if flashlight_recharge_timer <= 0:
			DebugLogger.debug(module_name, "Flashlight recharge delay complete, beginning recharge")
		return
	
	# Drain battery when on
	if flashlight_on:
		flashlight_battery -= flashlight_drain_rate * delta
		
		if flashlight_battery <= 0:
			flashlight_battery = 0
			flashlight_on = false
			flashlight_spot.visible = false
			flashlight_depleted = true
			flashlight_recharge_timer = flashlight_recharge_delay
			DebugLogger.debug(module_name, "Flashlight depleted! Starting recharge delay")
			
			# Play depleted sound
			if flashlight_click_sound and flashlight_audio:
				flashlight_audio.stream = flashlight_click_sound
				flashlight_audio.pitch_scale = 0.8
				flashlight_audio.play()
				flashlight_audio.pitch_scale = 1.0
	
	# Recharge when off
	elif flashlight_battery < flashlight_max_battery and flashlight_recharge_timer <= 0:
		flashlight_battery += flashlight_recharge_rate * delta
		
		if flashlight_battery >= flashlight_max_battery:
			flashlight_battery = flashlight_max_battery
			if flashlight_depleted:
				flashlight_depleted = false
				DebugLogger.debug(module_name, "Flashlight fully recharged")
	
	# Update UI
	_update_ui()

func _update_ui() -> void:
	if not ui_controller:
		return
	
	var show_meter = flashlight_battery < flashlight_max_battery
	var battery_percentage = (flashlight_battery / flashlight_max_battery) * 100.0
	ui_controller.update_flashlight_meter(battery_percentage, show_meter)
