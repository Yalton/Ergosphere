extends Control
class_name DiageticUIContent

## Base class for UI content inside diegetic UI SubViewports with splash screen support

## Reference to the main UI content
@export var main_ui: Control
## Reference to the splash screen node
@export var splash_screen: Control
@export var corruption_screen: Control

@export_group("Audio Feedback")
## Sound to play for positive interactions (success, confirmation, purchase)
@export var positive_sound: AudioStream
## Sound to play for negative interactions (error, denial, insufficient funds)
@export var negative_sound: AudioStream
## Sound to play for neutral interactions (navigation, selection, hover)
@export var neutral_sound: AudioStream
## Sound to play for victory/completion (level complete, task finished)
@export var victory_sound: AudioStream


signal splash_shown()
signal splash_hidden()
signal corruption_shown()
signal corruption_hidden()
func _ready() -> void:
	DebugLogger.register_module("DiageticUIContent")
	
	# Ensure splash is hidden by default
	if splash_screen:
		splash_screen.visible = false
	setup_corruption_ui()
func show_splash() -> void:
	if main_ui:
		main_ui.visible = false
		
	if splash_screen:
		splash_screen.visible = true
		splash_shown.emit()

func hide_splash() -> void:
	if splash_screen:
		splash_screen.visible = false
		
	if main_ui:
		main_ui.visible = true
		splash_hidden.emit()

## Abstract method for resetting UI to initial state. Override in child classes.
func reset_ui() -> void:
	DebugLogger.debug("DiageticUIContent", "Base reset_ui called - override in child class for custom behavior")
	pass

# Add to _ready() function
func setup_corruption_ui() -> void:
	# Ensure corruption screen is hidden by default
	if corruption_screen:
		corruption_screen.visible = false

## Show corruption screen
func show_corruption() -> void:
	# Hide main UI and splash
	if main_ui:
		main_ui.visible = false
	if splash_screen:
		splash_screen.visible = false
	
	# Show corruption screen
	if corruption_screen:
		corruption_screen.visible = true
		corruption_shown.emit()

## Hide corruption screen and restore normal UI
func hide_corruption() -> void:
	if corruption_screen:
		corruption_screen.visible = false
	
	# Restore main UI (not splash - that's controlled separately)
	if main_ui:
		main_ui.visible = true
		
	corruption_hidden.emit()


## Play positive feedback sound (success, confirmation, purchase)
func play_positive_sound() -> void:
	_play_ui_sound(positive_sound, "positive")

## Play negative feedback sound (error, denial, insufficient funds)
func play_negative_sound() -> void:
	_play_ui_sound(negative_sound, "negative")

## Play neutral feedback sound (navigation, selection, hover)
func play_neutral_sound() -> void:
	_play_ui_sound(neutral_sound, "neutral")

## Play victory/completion sound (level complete, task finished)
func play_victory_sound() -> void:
	_play_ui_sound(victory_sound, "victory")

## Internal method to play UI sounds with consistent settings
func _play_ui_sound(sound: AudioStream, sound_type: String) -> void:
	if sound and Audio:
		Audio.play_sound(sound, true, 1.0, 0.0, "UI")
		DebugLogger.debug("DiageticUIContent", "Playing %s sound" % sound_type)
	elif not sound:
		DebugLogger.debug("DiageticUIContent", "No %s sound configured" % sound_type)
