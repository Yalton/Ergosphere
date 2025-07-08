# PasswordLoginControl.gd
extends DiageticUIContent

## Signal emitted when access is granted and progress completes
signal login_completed

## UI References
@export_group("Login Screen")
@export var login_screen: Control
@export var password_field: LineEdit
@export var submit_button: Button
@export var error_label: Label
@export var status_label: Label

## Progress Screen
@export_group("Progress Screen")
@export var progress_screen: Control
@export var progress_bar: ProgressBar
@export var progress_label: Label

## Settings
@export_group("Settings")
@export var correct_password: String = "admin123"
@export var progress_duration: float = 5.0
@export var error_display_time: float = 2.0

## Audio
@export_group("Audio")
@export var button_click_sound: AudioStream
@export var success_sound: AudioStream
@export var error_sound: AudioStream

var is_busy: bool = false
var progress_tween: Tween
var module_name: String = "PasswordLoginControl"
var login_successful: bool = false

func _ready() -> void:
	DebugLogger.register_module(module_name, true)
	
	# Setup initial state
	_setup_login_screen()
	_setup_progress_screen()
	_show_login_screen()
	
	DebugLogger.debug(module_name, "Password login control initialized")

func _setup_login_screen() -> void:
	if not password_field or not submit_button:
		DebugLogger.error(module_name, "Required login UI elements not assigned!")
		return
	
	# Connect signals
	submit_button.pressed.connect(_on_submit_pressed)
	password_field.text_submitted.connect(_on_password_submitted)
	
	# Setup UI
	if error_label:
		error_label.text = ""
		error_label.visible = false
	
	if status_label:
		status_label.text = "Enter Password:"
	
	# Focus password field
	password_field.grab_focus()

func _setup_progress_screen() -> void:
	if progress_screen:
		progress_screen.visible = false
	
	if progress_bar:
		progress_bar.value = 0
		progress_bar.max_value = 100

func _show_login_screen() -> void:
	if login_screen:
		login_screen.visible = true
	if progress_screen:
		progress_screen.visible = false
	
	# Clear and focus password field
	if password_field:
		password_field.clear()
		password_field.grab_focus()

func _show_progress_screen() -> void:
	if login_screen:
		login_screen.visible = false
	if progress_screen:
		progress_screen.visible = true
	
	if progress_label:
		progress_label.text = "Accessing System..."

func _on_submit_pressed() -> void:
	DebugLogger.debug(module_name, "_on_submit_pressed called")
	if is_busy:
		DebugLogger.debug(module_name, "Already processing, ignoring submit")
		return
	
	_submit_password()

func _on_password_submitted(text: String) -> void:
	DebugLogger.debug(module_name, "_on_password_submitted called with text: " + text)
	if is_busy:
		DebugLogger.debug(module_name, "Already processing, ignoring enter key")
		return
	
	_submit_password()

func _submit_password() -> void:
	DebugLogger.debug(module_name, "_submit_password called")
	
	var password = password_field.text.strip_edges()
	DebugLogger.debug(module_name, "Password entered (length): " + str(password.length()))
	
	if password.is_empty():
		DebugLogger.warning(module_name, "Password is empty")
		_show_error_message("Password cannot be empty")
		return
	
	is_busy = true
	DebugLogger.debug(module_name, "Set is_busy = true")
	
	# Play button sound
	if button_click_sound:
		Audio.play_sound(button_click_sound, true, 1.0, 0.0, "SFX")
		DebugLogger.debug(module_name, "Played button sound")
	
	# Disable submit button
	if submit_button:
		submit_button.disabled = true
		DebugLogger.debug(module_name, "Disabled submit button")
	
	# Check password
	if password == correct_password:
		DebugLogger.info(module_name, "Password correct!")
		_show_success()
	else:
		DebugLogger.info(module_name, "Password incorrect!")
		_show_error()

func _show_success() -> void:
	DebugLogger.debug(module_name, "Showing success and starting progress")
	
	# Mark login as successful
	login_successful = true
	
	# Play success sound
	if success_sound:
		Audio.play_sound(success_sound, true, 1.0, 0.0, "SFX")
	
	# Show progress screen
	_show_progress_screen()
	
	# Start progress animation
	_start_progress()

func _show_error() -> void:
	DebugLogger.debug(module_name, "Showing error")
	
	# Play error sound
	if error_sound:
		Audio.play_sound(error_sound, true, 1.0, 0.0, "SFX")
	
	# Show error message
	_show_error_message("Incorrect Password")
	
	# Reset state
	is_busy = false
	if submit_button:
		submit_button.disabled = false
	
	# Clear password field and refocus
	if password_field:
		password_field.clear()
		password_field.grab_focus()
		DebugLogger.debug(module_name, "Password field cleared and focused")

func _show_error_message(message: String) -> void:
	if not error_label:
		return
	
	error_label.text = message
	error_label.visible = true
	
	# Hide error after delay
	var timer = get_tree().create_timer(error_display_time)
	timer.timeout.connect(_hide_error)

func _hide_error() -> void:
	if error_label:
		error_label.visible = false
		error_label.text = ""

func _start_progress() -> void:
	if not progress_bar:
		return
	
	progress_bar.value = 0
	
	# Create tween for progress
	progress_tween = create_tween()
	progress_tween.tween_method(_update_progress, 0.0, 100.0, progress_duration)
	progress_tween.finished.connect(_on_progress_complete)

func _update_progress(value: float) -> void:
	if progress_bar:
		progress_bar.value = value
	
	if progress_label:
		var percent = int(value)
		progress_label.text = "Accessing System... " + str(percent) + "%"

func _on_progress_complete() -> void:
	DebugLogger.info(module_name, "Progress complete, login successful")
	
	if progress_label:
		progress_label.text = "Access Granted!"
	
	is_busy = false
	
	# Emit signal for task completion
	login_completed.emit()

func set_password(new_password: String) -> void:
	correct_password = new_password
	DebugLogger.debug(module_name, "Password updated")

# Public method to focus password field
func focus_password_field() -> void:
	if password_field:
		password_field.grab_focus()
		DebugLogger.debug(module_name, "Password field focused")
