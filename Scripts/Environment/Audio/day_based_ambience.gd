extends Node

## Starts playing when current day >= start day
@export var enable_debug: bool = true
var module_name: String = "DayAmbientAudio"

## Day to start playing this audio track
@export var start_day: int = 0

## Reference to the AudioStreamPlayer to control
@export var audio_player: AudioStreamPlayer

var has_started: bool = false

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Check every 5 seconds
	var timer = CommonUtils.create_timer(self, 5.0, true, true)
	timer.timeout.connect(_check_day)
	_check_day() # Initial check

func _check_day() -> void:
	if has_started or not audio_player:
		return
		
	var current_day = _get_current_day()
	
	if current_day >= start_day:
		audio_player.play()
		has_started = true
		DebugLogger.info(module_name, "Started audio on day " + str(current_day))

func _get_current_day() -> int:
	if GameManager and GameManager.has_method("get_current_day"):
		return GameManager.get_current_day()
	return 0
