# GameOverScreen.gd
extends Control

signal restart_requested
signal menu_requested

@export_file("*.tscn") var main_menu_path: String

@onready var restart_button: Button = $HBoxContainer/VBoxContainer/RestartButton
@onready var main_menu_button: Button = $HBoxContainer/VBoxContainer/MainMenuButton
@onready var score_label: Label = $HBoxContainer/VBoxContainer/ScoreLabel
@onready var high_score_label: Label = $HBoxContainer/VBoxContainer/HighScoreLabel

func _ready() -> void:
	# Connect button signals
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_menu_pressed)
	hide()

func _on_restart_pressed() -> void:
	restart_requested.emit()

func _on_menu_pressed() -> void:
	#menu_requested.emit()
	
	# Use the global transition manager if available
	if TransitionManager:
		TransitionManager.transition_to_scene(main_menu_path)
	else:
		# Fallback to direct scene change
		print("Warning: GlobalTransitionManager not found, using direct scene change")
		get_tree().change_scene_to_file(main_menu_path)

# Update to show final score and high score
func show_score(final_score: int) -> void:
	var is_high_score = HighScoreManager.save_high_score(final_score)
	
	score_label.text = "Score: " + str(final_score)
	high_score_label.text = "High Score: " + str(HighScoreManager.get_high_score())
	
	if is_high_score:
		high_score_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
		high_score_label.text += " NEW!"
	else:
		high_score_label.remove_theme_color_override("font_color")
	
	show()
