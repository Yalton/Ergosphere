# PasswordDiegeticUI.gd
extends DiageticTextInputUI

## The correct password
@export var correct_password: String = "admin123"

var password_control: Control

func _ready() -> void:
	super._ready()
	module_name = "PasswordDiegeticUI"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Find password control in SubViewport
	if sub_viewport and sub_viewport.get_child_count() > 0:
		password_control = sub_viewport.get_child(0)
		
		# Set password on control
		if password_control.has_method("set_password"):
			password_control.set_password(correct_password)
		elif password_control.has_property("correct_password"):
			password_control.correct_password = correct_password
		
		DebugLogger.debug(module_name, "Found password control, set password")
	
	DebugLogger.debug(module_name, "Password diegetic UI initialized")

# Override to handle ESC to exit
func _unhandled_input(event: InputEvent) -> void:
	if !is_player_interacting:
		return
	
	# ESC to exit
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		DebugLogger.debug(module_name, "ESC pressed, ending interaction")
		end_interaction()
		get_viewport().set_input_as_handled()
		return
	
	# Forward keyboard events to SubViewport
	if capture_keyboard_input and event is InputEventKey:
		if typing_audio and event.pressed and not event.echo:
			typing_audio.play()
		
		if sub_viewport:
			sub_viewport.push_input(event)
		
		get_viewport().set_input_as_handled()
		return
	
	# Handle mouse events
	if !(event is InputEventMouseButton or event is InputEventMouseMotion):
		if sub_viewport:
			sub_viewport.push_input(event)
