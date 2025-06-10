extends Control
class_name RhythmGameUI

## Signal emitted when the game ends with the final score percentage
signal game_finished(score_percentage: float)

## Signal emitted when the game is cancelled
signal game_cancelled()

## Reference to the lane controller node
@export var lane_controller: Node

## Total number of notes to spawn during the game
@export var total_notes: int = 20

## Duration of the game in seconds
@export var game_duration: float = 30.0

## Minimum time between note spawns
@export var min_spawn_interval: float = 0.5

## Maximum time between note spawns
@export var max_spawn_interval: float = 2.0

@export_group("UI Elements")
## Label to display level and status
@export var status_label: Label

## Progress bar for level completion
@export var level_progress_bar: ProgressBar

## Progress bar for hit percentage
@export var hit_percentage_bar: ProgressBar

@export_group("Audio")
## Sound played when a note is hit
@export var note_hit_sound: AudioStream

## Sound played when a note is missed
@export var note_miss_sound: AudioStream

## Sound played when level is completed
@export var level_complete_sound: AudioStream

@export_group("Camera")
## Node3D that defines camera position/rotation for rhythm game
@export var camera_position_node: Node3D

## Duration for camera transitions
@export var camera_transition_duration: float = 1.5

var notes_spawned: int = 0
var notes_hit: int = 0
var notes_missed: int = 0
var game_active: bool = false
var spawn_timer: float = 0.0
var next_spawn_time: float = 0.0
var game_timer: float = 0.0
var current_level: int = 1
var has_played_today: bool = false
var player_controller: Player = null

# Audio players
var hit_audio_player: AudioStreamPlayer
var miss_audio_player: AudioStreamPlayer
var complete_audio_player: AudioStreamPlayer

func _ready():
	DebugLogger.register_module("RhythmGameUI")
	visible = false
	
	# Setup audio players
	hit_audio_player = AudioStreamPlayer.new()
	hit_audio_player.bus = "SFX"
	add_child(hit_audio_player)
	
	miss_audio_player = AudioStreamPlayer.new()
	miss_audio_player.bus = "SFX"
	add_child(miss_audio_player)
	
	complete_audio_player = AudioStreamPlayer.new()
	complete_audio_player.bus = "SFX"
	add_child(complete_audio_player)
	
	if lane_controller:
		lane_controller.note_hit.connect(_on_note_hit)
		lane_controller.note_missed.connect(_on_note_missed)
	
	# Connect to day reset
	if GameManager:
		GameManager.day_reset.connect(_on_day_reset)
	
	# Update UI
	_update_ui()

func _on_day_reset():
	# If the game was played, increment level
	if has_played_today:
		current_level += 1
		DebugLogger.log_message("RhythmGameUI", "Day reset - advancing to level %d" % current_level)
	
	# Reset play status
	has_played_today = false
	DebugLogger.log_message("RhythmGameUI", "Day reset - game available again")

func _process(delta):
	if not game_active:
		return
	
	game_timer += delta
	spawn_timer += delta
	
	# Update progress bar
	if level_progress_bar:
		var progress = float(notes_hit + notes_missed) / float(total_notes)
		level_progress_bar.value = progress * 100
	
	# Check if we should spawn a new note
	if spawn_timer >= next_spawn_time and notes_spawned < total_notes:
		_spawn_note()
		spawn_timer = 0.0
		next_spawn_time = randf_range(min_spawn_interval, max_spawn_interval)
	
	# Check if game should end
	if notes_spawned >= total_notes and notes_hit + notes_missed >= total_notes:
		_end_game()

func _input(event):
	if not game_active or not visible:
		return
	
	# Check for exit
	if event.is_action_pressed("interact") or event.is_action_pressed("menu"):
		DebugLogger.log_message("RhythmGameUI", "Player exited rhythm game")
		_cancel_game()
		get_viewport().set_input_as_handled()
		return
	
	if event is InputEventKey and event.pressed:
		var lane_index = -1
		
		match event.keycode:
			KEY_A:
				lane_index = 0
			KEY_S:
				lane_index = 1
			KEY_D:
				lane_index = 2
			KEY_F:
				lane_index = 3
		
		if lane_index >= 0:
			DebugLogger.log_message("RhythmGameUI", "Key pressed for lane %d" % lane_index)
			lane_controller.check_hit(lane_index)

func can_play():
	return not has_played_today

func start_game():
	if has_played_today:
		DebugLogger.log_message("RhythmGameUI", "Cannot play - already played today")
		return
	
	DebugLogger.log_message("RhythmGameUI", "Starting rhythm game level %d" % current_level)
	
	visible = true
	game_active = true
	notes_spawned = 0
	notes_hit = 0
	notes_missed = 0
	game_timer = 0.0
	spawn_timer = 0.0
	
	# Reset progress bars
	if level_progress_bar:
		level_progress_bar.value = 0
	if hit_percentage_bar:
		hit_percentage_bar.value = 0
	
	# Adjust difficulty based on level
	_apply_level_difficulty()
	
	next_spawn_time = randf_range(min_spawn_interval, max_spawn_interval)
	
	_update_ui()

func _apply_level_difficulty():
	# Increase difficulty with level
	var difficulty_multiplier = 1.0 + (current_level - 1) * 0.2
	
	# More notes at higher levels
	total_notes = int(20 + (current_level - 1) * 5)
	
	# Faster spawning at higher levels
	min_spawn_interval = max(0.3, 0.5 / difficulty_multiplier)
	max_spawn_interval = max(0.8, 2.0 / difficulty_multiplier)
	
	# Increase note speed
	if lane_controller and lane_controller.has_method("set_note_speed"):
		var base_speed = 300.0
		var new_speed = base_speed * difficulty_multiplier
		lane_controller.set_note_speed(new_speed)
	
	DebugLogger.log_message("RhythmGameUI", "Level %d: %d notes, spawn interval %.1f-%.1f" % 
		[current_level, total_notes, min_spawn_interval, max_spawn_interval])

func _spawn_note():
	var lane_index = randi() % 4
	lane_controller.spawn_note(lane_index)
	notes_spawned += 1
	DebugLogger.log_message("RhythmGameUI", "Spawned note %d/%d in lane %d" % [notes_spawned, total_notes, lane_index])

func _on_note_hit(lane_index: int):
	notes_hit += 1
	
	# Play hit sound
	if note_hit_sound and hit_audio_player:
		hit_audio_player.stream = note_hit_sound
		hit_audio_player.play()
	
	# Update hit percentage
	if hit_percentage_bar:
		var hit_percentage = float(notes_hit) / float(max(1, notes_hit + notes_missed)) * 100.0
		hit_percentage_bar.value = hit_percentage
	
	DebugLogger.log_message("RhythmGameUI", "Note hit! Total hits: %d" % notes_hit)

func _on_note_missed(lane_index: int):
	notes_missed += 1
	
	# Play miss sound
	if note_miss_sound and miss_audio_player:
		miss_audio_player.stream = note_miss_sound
		miss_audio_player.play()
	
	# Update hit percentage
	if hit_percentage_bar:
		var hit_percentage = float(notes_hit) / float(max(1, notes_hit + notes_missed))
		hit_percentage_bar.value = hit_percentage
	
	DebugLogger.log_message("RhythmGameUI", "Note missed! Total misses: %d" % notes_missed)

func _update_ui():
	if status_label:
		if has_played_today:
			status_label.text = "Level %d - Completed Today" % current_level
		else:
			status_label.text = "Level %d" % current_level

func _end_game():
	game_active = false
	var score_percentage = (float(notes_hit) / float(total_notes)) * 100.0
	DebugLogger.log_message("RhythmGameUI", "Game ended! Score: %.1f%%" % score_percentage)
	
	# Play complete sound
	if level_complete_sound and complete_audio_player:
		complete_audio_player.stream = level_complete_sound
		complete_audio_player.play()
	
	# Mark as played today
	has_played_today = true
	
	# Update UI with final score
	if status_label:
		status_label.text = "Level %d - Score: %.1f%%" % [current_level, score_percentage]
	
	# Wait before hiding and restoring controls
	await get_tree().create_timer(3.0).timeout
	
	visible = false
	
	game_finished.emit(score_percentage)

func _cancel_game():
	game_active = false
	
	# Clear any remaining notes
	if lane_controller and lane_controller.has_method("clear_all_notes"):
		lane_controller.clear_all_notes()
	
	visible = false
	
	game_cancelled.emit()

func _restore_player_control():
	if not player_controller:
		return
	
	# Re-enable player controls
	player_controller.is_interacting_with_ui = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Restore camera
	if player_controller.has_method("restore_camera_position"):
		player_controller.restore_camera_position(camera_transition_duration)
