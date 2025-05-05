# transition_manager.gd
extends Control
#class_name TransitionManager

signal fade_to_black_finished
signal fade_from_black_finished

@export var enable_debug: bool = false
@export var transition_audio: AudioStreamPlayer
var module_name: String = "TransitionManager"

@onready var color_rect: ColorRect = $ColorRect

const FADE_DURATION: float = 1.0 # Each fade direction takes 1 second

func _ready() -> void:
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	
	color_rect = $ColorRect
	if color_rect: 
		# Start with transparent black
		color_rect.color = Color(0, 0, 0, 0)
	
	hide()
	# Make sure it covers the whole screen

func fade_to_black() -> void:
	DebugLogger.debug(module_name, "Fading to black")
	show()
	var tween = create_tween()
	tween.tween_property(color_rect, "color",
		Color(0, 0, 0, 1.0), FADE_DURATION)
	await tween.finished
	fade_to_black_finished.emit()

func fade_from_black() -> void:
	DebugLogger.debug(module_name, "Fading from black")
	var tween = create_tween()
	tween.tween_property(color_rect, "color",
		Color(0, 0, 0, 0), FADE_DURATION)
	await tween.finished
	hide()
	fade_from_black_finished.emit()

# Modified to handle scene visibility
func transition_to_cutscene(prepare_cutscene_func: Callable, start_cutscene_func: Callable, hide_current_scene_func: Callable) -> void:
	# Start fade to black
	await fade_to_black()
	
	# Hide current scene and prepare cutscene while black
	hide_current_scene_func.call()
	prepare_cutscene_func.call()
	
	# Small delay to ensure preparation is complete
	await get_tree().create_timer(0.1).timeout
	
	# Start cutscene after fade is complete
	start_cutscene_func.call()
	
	# Start fade from black
	await fade_from_black()

# Modified to handle scene visibility
func transition_from_cutscene(prepare_next_scene_func: Callable, hide_cutscene_func: Callable, start_next_scene_func: Callable) -> void:
	# Hide cutscene and prepare next scene while black
	await fade_to_black()
	
	hide_cutscene_func.call()
	prepare_next_scene_func.call()
	
	await get_tree().create_timer(0.1).timeout
	
	await fade_from_black()
	start_next_scene_func.call()

# Modified to handle scene visibility
func transition_to_next_level(prepare_level_func: Callable, hide_current_scene_func: Callable, start_level_func: Callable) -> void:
	await fade_to_black()
	
	hide_current_scene_func.call()
	prepare_level_func.call()
	
	await get_tree().create_timer(0.1).timeout
	
	await fade_from_black()
	start_level_func.call()
	
# Transition to shop
# Transition to shop
func transition_to_shop(prepare_func: Callable, start_func: Callable, hide_current_func: Callable) -> void:
	# Start with a fade out and wait for it to complete
	await fade_to_black()
	
	# Hide current UI
	hide_current_func.call()
	
	# Prepare shop
	prepare_func.call()
	
	# Small delay to ensure preparation is complete
	await get_tree().create_timer(0.1).timeout
	
	# Start the shop (this happens before the fade completes)
	start_func.call()
	
	# Fade back in
	await fade_from_black()

# Transition from shop back to level complete screen
func transition_from_shop(hide_shop_func: Callable, show_level_complete_func: Callable) -> void:
	# Start with a fade out and wait for it to complete
	await fade_to_black()
	
	# Hide shop
	hide_shop_func.call()
	
	# Show level complete screen
	show_level_complete_func.call()
	
	# Small delay to ensure UI changes are processed
	await get_tree().create_timer(0.1).timeout
	
	# Fade back in
	await fade_from_black()

# Generic transition method that can be used for any scene change
func transition_between_scenes(hide_current_func: Callable, prepare_next_func: Callable, show_next_func: Callable) -> void:
	await fade_to_black()
	
	hide_current_func.call()
	prepare_next_func.call()
	
	await get_tree().create_timer(0.1).timeout
	
	await fade_from_black()
	show_next_func.call()

# Method for transitioning between scenes
func transition_to_scene(next_scene_path: String) -> void:
	print("Transitioning to scene: ", next_scene_path)
	transition_audio.play()
	await fade_to_black()
	get_tree().change_scene_to_file(next_scene_path)
	await fade_from_black()
	
