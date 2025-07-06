extends Control
class_name PauseMenu

# Signals
signal resume_requested
signal menu_requested

## Path to the main menu scene file
@export_file("*.tscn") var main_menu_path: String
## Enable debug logging for this module
@export var enable_debug: bool = false
## Module name for debug logging
@export var module_name: String = "PauseMenu"

# Menu references
@onready var pause_menu = $PauseMenu
@onready var resume_button = $PauseMenu/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/ResumeButton
@onready var options_button = $PauseMenu/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/OptionsButton
@onready var controls_button = $PauseMenu/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/ControlsButton
@onready var main_menu_button = $PauseMenu/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/MainMenuButton

# Sub-menus
@onready var options_ui_control: OptionsUIControl = $Options
@onready var controls_menu = $Controls
@onready var controls_back_button = $Controls/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/BackButton

# State tracking
var is_paused: bool = false
var active_menu: Control = null

func _ready() -> void:
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
		
	# Set the process mode to ensure it works during pauses
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Make all UI elements processable during pause
	_set_all_children_process_mode(self, Node.PROCESS_MODE_ALWAYS as Node.ProcessMode)
	
	# Connect pause menu signals
	resume_button.pressed.connect(_on_resume_pressed)
	options_button.pressed.connect(_on_options_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	main_menu_button.pressed.connect(_on_menu_pressed)
	
	# Connect options UI control back button
	if options_ui_control:
		options_ui_control.back_pressed.connect(_on_options_back_pressed)
		DebugLogger.debug(module_name, "Connected to OptionsUIControl")
	else:
		DebugLogger.error(module_name, "OptionsUIControl not found!")
	
	# Connect controls menu signals
	controls_back_button.pressed.connect(_on_controls_back_pressed)
	
	# Initially hide all menus
	pause_menu.hide()
	if options_ui_control:
		options_ui_control.hide()
	controls_menu.hide()
	visible = false
	
	DebugLogger.info(module_name, "PauseMenu system initialized")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if is_paused:
		unpause()
	else:
		pause()

# Recursively set process mode for all UI children
func _set_all_children_process_mode(node: Node, mode: Node.ProcessMode) -> void:
	for child in node.get_children():
		child.process_mode = mode
		_set_all_children_process_mode(child, mode)

func pause() -> void:
	if is_paused:
		return
		
	DebugLogger.debug(module_name, "Pausing game")
		
	# Release the mouse for menu interaction
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Pause the game
	get_tree().paused = true
	
	# Show pause menu (hide others)
	active_menu = pause_menu
	pause_menu.show()
	if options_ui_control:
		options_ui_control.hide()
	controls_menu.hide()
	visible = true
	
	# Update pause state
	is_paused = true
	
	DebugLogger.info(module_name, "Game paused")

func unpause() -> void:
	if !is_paused:
		return
		
	DebugLogger.debug(module_name, "Unpausing game")
		
	# Unpause the game
	get_tree().paused = false
	
	# Hide all menus
	pause_menu.hide()
	if options_ui_control:
		options_ui_control.hide()
	controls_menu.hide()
	visible = false
	active_menu = null
	
	# Recapture the mouse for gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Update pause state
	is_paused = false
	
	DebugLogger.info(module_name, "Game unpaused")

# Pause Menu Button Handlers
func _on_resume_pressed() -> void:
	DebugLogger.debug(module_name, "Resume pressed")
	unpause()
	resume_requested.emit()

func _on_options_pressed() -> void:
	DebugLogger.debug(module_name, "Options pressed - showing options menu")
	
	# Switch from pause menu to options menu
	pause_menu.hide()
	if options_ui_control:
		options_ui_control.show()
		options_ui_control.refresh_settings()
	controls_menu.hide()
	active_menu = options_ui_control

func _on_controls_pressed() -> void:
	DebugLogger.debug(module_name, "Controls pressed - showing controls menu")
	
	# Switch from pause menu to controls menu
	pause_menu.hide()
	if options_ui_control:
		options_ui_control.hide()
	controls_menu.show()
	active_menu = controls_menu
	
	# Give focus to the back button for better UI navigation
	controls_back_button.grab_focus()

func _on_menu_pressed() -> void:
	DebugLogger.debug(module_name, "Main menu pressed - returning to main menu")
	
	# Unpause first
	unpause()
	
	# Signal that we want to go to main menu
	menu_requested.emit()
	
	# If main_menu_path is set, change to that scene
	if main_menu_path != "":
		DebugLogger.info(module_name, "Changing scene to: " + main_menu_path)
		get_tree().change_scene_to_file(main_menu_path)

# Options back handler
func _on_options_back_pressed() -> void:
	DebugLogger.debug(module_name, "Returning from options to pause menu")
	
	# Switch back to pause menu
	if options_ui_control:
		options_ui_control.hide()
	controls_menu.hide()
	pause_menu.show()
	active_menu = pause_menu

# Controls Menu Button Handler
func _on_controls_back_pressed() -> void:
	DebugLogger.debug(module_name, "Returning from controls to pause menu")
	
	# Switch back to pause menu
	controls_menu.hide()
	if options_ui_control:
		options_ui_control.hide()
	pause_menu.show()
	active_menu = pause_menu
