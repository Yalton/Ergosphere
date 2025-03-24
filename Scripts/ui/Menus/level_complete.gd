# Updated level_complete.gd

extends Control

signal next_level_requested
signal menu_requested
signal shop_requested

@export_file("*.tscn") var main_menu_path: String

@onready var next_level_button: Button = $HBoxContainer/VBoxContainer/NextLevel
@onready var shop_button: Button = $HBoxContainer/VBoxContainer/UpgradeShop
@onready var main_menu_button: Button = $HBoxContainer/VBoxContainer/MainMenu
@onready var title_label : Label = $HBoxContainer/VBoxContainer/Label
# Track if shop has been visited this level
var shop_visited_this_level: bool = false
var current_level: int = 1

func _ready() -> void:
	next_level_button.pressed.connect(_on_next_level_pressed)
	main_menu_button.pressed.connect(_on_menu_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	hide()

# Function to set the current level and update display
func set_level(level_number: int) -> void:
	current_level = level_number
	if title_label:
		title_label.text = "Level " + str(current_level) + " Complete"
		
func _on_next_level_pressed() -> void:
	next_level_requested.emit()
	
func _on_menu_pressed() -> void:
	menu_requested.emit()
	
	# Use the global transition manager if available
	if TransitionManager:
		TransitionManager.transition_to_scene(main_menu_path)
	else:
		# Fallback to direct scene change
		print("Warning: GlobalTransitionManager not found, using direct scene change")
		get_tree().change_scene_to_file(main_menu_path)

func _on_shop_pressed() -> void:
	shop_requested.emit()
	shop_button.hide()  # Hide the shop button after it's been used
	shop_visited_this_level = true

# Function to reset the shop button visibility when a new level completes
func reset_shop_button() -> void:
	shop_visited_this_level = false
	shop_button.show()
	
# Function to show the screen and configure buttons
#func show() -> void:
	## If shop has been visited this level, keep the button hidden
	#if shop_visited_this_level:
		#shop_button.hide()
	#else:
		#shop_button.show()
	#
	## Show the screen itself
	#super.show()
