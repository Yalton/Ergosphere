# PasswordDiegeticUI.gd
extends DiageticTextInputUI

## The correct password
@export var correct_password: String = "admin123"

var password_control: Control

func _ready() -> void:
	super._ready()
	module_name = "PasswordDiegeticUI"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Find task aware component
	task_aware_component = get_node_or_null("TaskAwareComponent")
	
	# Find password control in SubViewport
	if sub_viewport and sub_viewport.get_child_count() > 0:
		password_control = sub_viewport.get_child(0)
		
		# Set password on control
		password_control.set_password(correct_password)
		password_control.correct_password = correct_password
	
		# Connect to completion signal
		password_control.login_completed.connect(_on_login_completed)
		DebugLogger.debug(module_name, "Connected to login completion signal")
		
		DebugLogger.debug(module_name, "Found password control, set password")
	
	DebugLogger.debug(module_name, "Password diegetic UI initialized")

func _on_login_completed() -> void:
	DebugLogger.info(module_name, "Login completed - completing task")
	
	# Complete the task if we have a task component
	if task_aware_component:
		task_aware_component.complete_task()

# Override start_interaction to focus password field and show hint
func start_interaction() -> void:
	super.start_interaction()
	
	# Focus the password field when interaction starts
	if password_control and password_control.password_field:
		DebugLogger.debug(module_name, "Focusing password field")
		password_control.password_field.grab_focus()
	
# Override to handle ESC to exit and TAB navigation
func _unhandled_input(event: InputEvent) -> void:
	if !is_player_interacting:
		return
	
	# ESC to exit
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		DebugLogger.debug(module_name, "ESC pressed, ending interaction")
		end_interaction()
		get_viewport().set_input_as_handled()
		return
	
	# Forward all input events to SubViewport when interacting
	if sub_viewport:
		sub_viewport.push_input(event)
		
		# Play typing sound for keyboard events
		if capture_keyboard_input and event is InputEventKey and event.pressed and not event.echo:
			if typing_audio:
				typing_audio.play()
	
	get_viewport().set_input_as_handled()
