# PauseMenu.gd
extends Control

signal resume_requested
signal options_requested(caller_name: String)
signal menu_requested

@export_file("*.tscn") var main_menu_path: String
@export var options_menu: Control
@export var ui_elements_to_hide: Array[Control] = []
# Reference to the player controller (optional)
@export var player_controller: Player

@onready var resume_button: Button = $HBoxContainer/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/ResumeButton
@onready var options_button: Button = $HBoxContainer/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/OptionsButton
@onready var main_menu_button: Button = $HBoxContainer/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/MainMenuButton

var is_paused: bool = false
var visible_elements: Array = []

func _ready() -> void:
	# Set this menu to always process
	process_mode = PROCESS_MODE_ALWAYS
	
	# Make sure all child UI elements process while paused
	_set_all_children_process_mode(self, PROCESS_MODE_ALWAYS)
	
	# Connect button signals
	resume_button.pressed.connect(_on_resume_pressed)
	options_button.pressed.connect(_on_options_pressed)
	main_menu_button.pressed.connect(_on_menu_pressed)
	hide()

# Recursively set process mode for all UI children
func _set_all_children_process_mode(node: Node, mode: int) -> void:
	for child in node.get_children():
		if child is Control:
			child.process_mode = mode
			_set_all_children_process_mode(child, mode)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # ESC key by default
		# Only toggle pause if options menu isn't visible
		if options_menu and options_menu.visible:
			return
		toggle_pause()

func toggle_pause() -> void:
	is_paused = !is_paused
	
	if is_paused:
		pause_game()
	else:
		resume_game()

func pause_game() -> void:
	# Store which UI elements are currently visible before hiding them
	visible_elements.clear()
	
	for element in ui_elements_to_hide:
		if element and element.visible:
			visible_elements.append(element)
			element.hide()
	
	# Release mouse capture if we have a player controller
	if player_controller:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		# Default behavior if no player controller is set
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	get_tree().paused = true
	show()

func resume_game() -> void:
	# Restore visibility only to elements that were visible before pausing
	for element in visible_elements:
		if element:
			element.show()
	
	visible_elements.clear()
	
	# Recapture mouse if we have a player controller
	if player_controller:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	get_tree().paused = false
	hide()
	
func _on_resume_pressed() -> void:
	resume_requested.emit()
	resume_game()

func _on_options_pressed() -> void:
	# Show options menu with reference to this menu
	if options_menu:
		options_menu.show_options(self)

func _on_menu_pressed() -> void:
	# First unpause the game to prevent issues
	resume_game()
	menu_requested.emit()
	
	# Use the global transition manager if available
	if TransitionManager:
		TransitionManager.transition_to_scene(main_menu_path)
	else:
		# Fallback to direct scene change
		print("Warning: GlobalTransitionManager not found, using direct scene change")
		get_tree().change_scene_to_file(main_menu_path)
