extends Control
class_name DiageticUIContent

## Base class for UI content inside diegetic UI SubViewports with splash screen support

## Reference to the main UI content
@export var main_ui: Control
## Reference to the splash screen node
@export var splash_screen: Control

signal splash_shown()
signal splash_hidden()

func _ready() -> void:
	DebugLogger.register_module("DiageticUIContent")
	
	# Ensure splash is hidden by default
	if splash_screen:
		splash_screen.visible = false

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
