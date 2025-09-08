extends Decal
class_name PulsatingDecal

## Controls pulsating emission effect for decals

@export_group("Pulse Settings")
## Time for one complete pulse cycle (0 to max to 0)
@export var pulse_duration: float = 1.0
## Maximum emission energy during pulse
@export var max_emission_energy: float = 1.5
## Minimum emission energy during pulse
@export var min_emission_energy: float = 0.0

@export_group("Fade Settings")
## Time to fade in when showing
@export var fade_in_duration: float = 0.5
## Time to fade out when hiding
@export var fade_out_duration: float = 0.5

var is_pulsating: bool = false
var pulse_tween: Tween
var visibility_tween: Tween
var original_modulate: Color

func _ready() -> void:
	DebugLogger.register_module("PulsatingDecal")
	
	# Store original modulate
	original_modulate = modulate
	
	# Start hidden
	visible = true
	modulate.a = 0.0
	emission_energy = 0.0


func show_decal() -> void:
	DebugLogger.log_message("PulsatingDecal", "Showing decal")
	
	# Kill any existing visibility tween
	if visibility_tween and visibility_tween.is_valid():
		visibility_tween.kill()
	
	# Make visible first
	visible = true
	
	# Create fade in tween
	visibility_tween = create_tween()
	visibility_tween.set_parallel(true)
	visibility_tween.tween_property(self, "modulate:a", original_modulate.a, fade_in_duration)
	visibility_tween.tween_property(self, "emission_energy", min_emission_energy, fade_in_duration)
	
	# Start pulsating after fade in
	visibility_tween.finished.connect(_start_pulsating)

func hide_decal() -> void:
	DebugLogger.log_message("PulsatingDecal", "Hiding decal")
	
	# Stop pulsating
	_stop_pulsating()
	
	# Kill any existing visibility tween
	if visibility_tween and visibility_tween.is_valid():
		visibility_tween.kill()
	
	# Create fade out tween
	visibility_tween = create_tween()
	visibility_tween.set_parallel(true)
	visibility_tween.tween_property(self, "modulate:a", 0.0, fade_out_duration)
	visibility_tween.tween_property(self, "emission_energy", 0.0, fade_out_duration)
	
	# Hide completely after fade out
	visibility_tween.finished.connect(func(): visible = false)

func _start_pulsating() -> void:
	if is_pulsating:
		return
	
	DebugLogger.log_message("PulsatingDecal", "Starting pulse")
	is_pulsating = true
	_create_pulse_tween()

func _stop_pulsating() -> void:
	if not is_pulsating:
		return
	
	DebugLogger.log_message("PulsatingDecal", "Stopping pulse")
	is_pulsating = false
	
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()

func _create_pulse_tween() -> void:
	if not is_pulsating:
		return
	
	# Kill existing pulse tween
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	
	# Create looping pulse tween
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	
	# Pulse from min to max to min
	pulse_tween.tween_property(self, "emission_energy", max_emission_energy, pulse_duration / 2.0)
	pulse_tween.tween_property(self, "emission_energy", min_emission_energy, pulse_duration / 2.0)
