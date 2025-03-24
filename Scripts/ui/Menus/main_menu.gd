# MainMenu.gd
extends Control

# Export the path to your game scene
@export var play_game_audio: AudioStream
@export_file("*.tscn") var game_scene_path: String
@export var options_menu: Control
@onready var play_game_button: Button = $HBoxContainer/VBoxContainer/PlayButton
@onready var options_button: Button = $HBoxContainer/VBoxContainer/OptionsButton
@onready var quit_button: Button = $HBoxContainer/VBoxContainer/QuitButton
@onready var score_label: Label = $HBoxContainer/Control/PanelContainer/Label

func _ready() -> void:
	# Make sure the mouse is visible when entering the main menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Connect button signals
	play_game_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	update_high_score_display()
	
	if options_menu:
		options_menu.hide()

func _on_play_pressed() -> void:
	print("Play button pressed, starting transition")
	Audio.play_sound(play_game_audio)
	
	# Use the global transition manager to handle scene transition
	if TransitionManager:
		# Using the global transition manager
		TransitionManager.transition_to_scene(game_scene_path)
		# Note: we don't queue_free here since the transition will handle it
	else:
		# Fallback to direct scene change if transition manager is not available
		print("Warning: GlobalTransitionManager not found, using direct scene change")
		get_tree().change_scene_to_file(game_scene_path)
		queue_free()

func _on_options_pressed() -> void:
	print("options pressed")
	# Show options menu with reference to this menu
	if options_menu:
		options_menu.show_options(self)
		
func _on_quit_pressed() -> void:
	# Quit the game
	get_tree().quit()

func update_high_score_display() -> void:
	# Access the singleton and get the high score
	if HighScoreManager:
		var score = HighScoreManager.get_high_score()
		score_label.text = "High Score: " + str(score)
	else:
		print("Warning: HighScoreManager singleton not found")
		score_label.text = "High Score: 0"
