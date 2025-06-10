extends StaticBody3D
class_name RhythmGame3DInteractable

## Reference to the rhythm game UI node in the scene
@export var rhythm_game_ui: RhythmGameUI

## Reference to the BasicInteractable component
@export var basic_interactable: InteractionComponent

## Text shown when playing the game
@export var play_text: String = "Play Rhythm Game"

## Text shown when game has already been played today
@export var already_played_text: String = "Come back tomorrow"

## Cooldown time after interaction ends
@export var interaction_cooldown: float = 1.0

@export_group("Camera")
## Node3D that defines camera position/rotation for rhythm game
@export var camera_position_node: Node3D

## Duration for camera transitions
@export var camera_transition_duration: float = 1.5

signal object_state_updated(text: String)

var player_interaction_component: PlayerInteractionComponent
var player_controller: Player = null
var is_in_cooldown: bool = false
var cooldown_timer: float = 0.0

func _ready():
	DebugLogger.register_module("RhythmGame3DInteractable")
	add_to_group("interactable")
	
	if rhythm_game_ui:
		rhythm_game_ui.game_finished.connect(_on_game_finished)
		rhythm_game_ui.game_cancelled.connect(_on_game_cancelled)
	
	# Update interaction text on ready
	_update_interaction_text()

func _process(delta):
	if is_in_cooldown:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			is_in_cooldown = false
			DebugLogger.log_message("RhythmGame3DInteractable", "Cooldown ended")

func interact(_player_interaction_component: PlayerInteractionComponent):
	player_interaction_component = _player_interaction_component
	
	# Don't interact during cooldown
	if is_in_cooldown:
		return
	
	if not rhythm_game_ui:
		return
	
	if not rhythm_game_ui.can_play():
		if player_interaction_component:
			player_interaction_component.send_hint("info", already_played_text)
		return
	
	# Find player controller
	player_controller = get_tree().get_first_node_in_group("player") as Player
	if not player_controller:
		DebugLogger.error("RhythmGame3DInteractable", "Could not find player controller!")
		return
	
	DebugLogger.log_message("RhythmGame3DInteractable", "Starting rhythm game")
	
	# Disable player movement
	player_controller.is_interacting_with_ui = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Move camera if configured
	if camera_position_node and player_controller.has_method("move_camera_to_position"):
		var target_pos = camera_position_node.global_position
		var target_rot = camera_position_node.global_rotation
		player_controller.move_camera_to_position(target_pos, target_rot, camera_transition_duration)
	
	# Start the rhythm game
	rhythm_game_ui.start_game()
	
	# Start cooldown
	_start_cooldown()

func _update_interaction_text():
	var text = play_text
	if rhythm_game_ui and not rhythm_game_ui.can_play():
		text = already_played_text
	
	if basic_interactable:
		basic_interactable.interaction_text = text
	
	object_state_updated.emit(text)

func _start_cooldown():
	is_in_cooldown = true
	cooldown_timer = interaction_cooldown
	DebugLogger.log_message("RhythmGame3DInteractable", "Starting cooldown for %.1f seconds" % interaction_cooldown)

func _on_game_finished(score_percentage: float):
	DebugLogger.log_message("RhythmGame3DInteractable", "Game finished with score: %.1f%%" % score_percentage)
	_restore_player_control()
	_update_interaction_text()

func _on_game_cancelled():
	DebugLogger.log_message("RhythmGame3DInteractable", "Game was cancelled")
	_restore_player_control()

func _restore_player_control():
	if not player_controller:
		return
	
	# Re-enable player controls
	player_controller.is_interacting_with_ui = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Restore camera
	if player_controller.has_method("restore_camera_position"):
		player_controller.restore_camera_position(camera_transition_duration)
