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

@export_group("Visual Debugging")
## ColorRect to visualize the hit zone across all lanes
@export var hit_zone_debug_rect: ColorRect

var notes_spawned: int = 0
var notes_hit: int = 0
var notes_missed: int = 0
var game_active: bool = false
var spawn_timer: float = 0.0
var next_spawn_time: float = 0.0
var game_timer: float = 0.0

var current_level: int = 1
var has_played_today: bool = false

var hit_audio_player: AudioStreamPlayer
var miss_audio_player: AudioStreamPlayer
var complete_audio_player: AudioStreamPlayer

# Track last spawn time per lane to prevent rapid spawning in same lane
var last_lane_spawn_times: Array[float] = [0.0, 0.0, 0.0, 0.0]
const MIN_LANE_SPAWN_INTERVAL: float = 1.0

func _ready():
	DebugLogger.register_module("RhythmGameUI")
	
	# Create audio players
	hit_audio_player = AudioStreamPlayer.new()
	miss_audio_player = AudioStreamPlayer.new()
	complete_audio_player = AudioStreamPlayer.new()
	add_child(hit_audio_player)
	add_child(miss_audio_player)
	add_child(complete_audio_player)
	
	# Connect to lane controller signals
	if lane_controller:
		lane_controller.note_hit.connect(_on_note_hit)
		lane_controller.note_missed.connect(_on_note_missed)
	
	# Create hit zone debug visualization
	_create_hit_zone_debug_rect()
	
	visible = false

func _create_hit_zone_debug_rect():
	if not hit_zone_debug_rect:
		hit_zone_debug_rect = ColorRect.new()
		hit_zone_debug_rect.name = "HitZoneDebugRect"
		hit_zone_debug_rect.color = Color(0.0, 1.0, 0.0, 0.3)  # Semi-transparent green
		hit_zone_debug_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hit_zone_debug_rect)
		
		# Set to high z-index to ensure it's on top
		hit_zone_debug_rect.z_index = 10
		hit_zone_debug_rect.show_behind_parent = false
	
	# Update position when visible
	if visible:
		_update_hit_zone_debug_rect()

func _update_hit_zone_debug_rect():
	if not hit_zone_debug_rect or not lane_controller or not lane_controller.lanes.size() > 0:
		return
	
	# Get the first and last lane to determine bounds
	var first_lane = lane_controller.lanes[0]
	var last_lane = lane_controller.lanes[lane_controller.lanes.size() - 1]
	
	if not first_lane or not last_lane:
		return
	
	# Get hit zone bounds from the first lane
	var hit_zone_bounds = first_lane.get_hit_zone_bounds() if first_lane.has_method("get_hit_zone_bounds") else {}
	
	if hit_zone_bounds.is_empty():
		# Fallback to old calculation
		var hit_zone_y = first_lane.hit_zone_center_y - first_lane.hit_zone_tolerance
		var hit_zone_height = first_lane.hit_zone_tolerance * 2.0
		
		# Get global positions of lanes relative to RhythmGameUI
		var first_lane_global_x = first_lane.global_position.x - global_position.x
		var last_lane_global_x = last_lane.global_position.x + last_lane.size.x - global_position.x
		var lane_global_y = first_lane.global_position.y - global_position.y
		
		# Set the debug rect position and size
		hit_zone_debug_rect.position = Vector2(first_lane_global_x, lane_global_y + hit_zone_y)
		hit_zone_debug_rect.size = Vector2(last_lane_global_x - first_lane_global_x, hit_zone_height)
	else:
		# Use actual hit zone panel bounds
		var hit_zone_top = hit_zone_bounds["top"]
		var hit_zone_bottom = hit_zone_bounds["bottom"]
		var hit_zone_height = hit_zone_bottom - hit_zone_top
		
		# Get global positions of lanes relative to RhythmGameUI
		var first_lane_global_x = first_lane.global_position.x - global_position.x
		var last_lane_global_x = last_lane.global_position.x + last_lane.size.x - global_position.x
		var lane_global_y = first_lane.global_position.y - global_position.y
		
		# Set the debug rect position and size
		hit_zone_debug_rect.position = Vector2(first_lane_global_x, lane_global_y + hit_zone_top)
		hit_zone_debug_rect.size = Vector2(last_lane_global_x - first_lane_global_x, hit_zone_height)
	
	DebugLogger.log_message("RhythmGameUI", "Hit zone debug rect - Pos: %v, Size: %v" % [hit_zone_debug_rect.position, hit_zone_debug_rect.size])

func _process(delta):
	if not game_active:
		return
	
	game_timer += delta
	spawn_timer += delta
	
	# Update progress bars
	if level_progress_bar:
		level_progress_bar.value = (float(notes_hit + notes_missed) / float(total_notes)) * 100.0
	
	# Check if we should spawn a new note
	if spawn_timer >= next_spawn_time and notes_spawned < total_notes:
		_spawn_note()
		spawn_timer = 0.0
		next_spawn_time = randf_range(min_spawn_interval, max_spawn_interval)
	
	# Check if game should end
	if notes_spawned >= total_notes and notes_hit + notes_missed >= total_notes:
		_end_game()

func _spawn_note():
	# Try to find a suitable lane that hasn't been used recently
	var available_lanes = []
	
	for i in range(4):
		# Check if enough time has passed since last spawn in this lane
		if game_timer - last_lane_spawn_times[i] >= MIN_LANE_SPAWN_INTERVAL:
			available_lanes.append(i)
	
	# If no lanes meet the time requirement, don't force spawn
	if available_lanes.is_empty():
		DebugLogger.log_message("RhythmGameUI", "No lanes available due to timing, waiting...")
		# Reduce the next spawn time to try again sooner
		next_spawn_time = min_spawn_interval * 0.5
		return
	
	# Shuffle available lanes to try them in random order
	available_lanes.shuffle()
	
	# Try to spawn in one of the available lanes
	var spawned = false
	for lane_index in available_lanes:
		if lane_controller.spawn_note(lane_index):
			# Update last spawn time for this lane
			last_lane_spawn_times[lane_index] = game_timer
			notes_spawned += 1
			spawned = true
			DebugLogger.log_message("RhythmGameUI", "Spawned note %d/%d in lane %d" % [notes_spawned, total_notes, lane_index])
			break
		else:
			DebugLogger.log_message("RhythmGameUI", "Lane %d rejected spawn" % lane_index)
	
	if not spawned:
		DebugLogger.log_message("RhythmGameUI", "Failed to spawn in any available lane, waiting...")
		# Reduce the next spawn time to try again sooner
		next_spawn_time = min_spawn_interval * 0.5



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
	
	# Reset lane spawn timers
	last_lane_spawn_times = [0.0, 0.0, 0.0, 0.0]
	
	# Reset progress bars
	if level_progress_bar:
		level_progress_bar.value = 0
	if hit_percentage_bar:
		hit_percentage_bar.value = 0
	
	# Apply difficulty based on level
	_apply_level_difficulty()
	
	next_spawn_time = randf_range(min_spawn_interval, max_spawn_interval)
	
	# Update hit zone debug rect after a frame to ensure lanes are properly sized
	await get_tree().process_frame
	
	# Force lanes to recalculate their positions
	for lane in lane_controller.lanes:
		if lane and lane.has_method("_calculate_positions"):
			lane._calculate_positions()
	
	_update_hit_zone_debug_rect()
	
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


func _on_note_hit(lane_index: int):
	notes_hit += 1
	
	# Play hit sound with pitch variation based on lane
	if note_hit_sound and hit_audio_player:
		hit_audio_player.stream = note_hit_sound
		
		# Pitch up based on lane index (0 = no change, 1 = +2 semitones, etc.)
		# Each semitone is approximately 1.0595 multiplier
		var pitch_multiplier = pow(1.0595, lane_index * 2)
		hit_audio_player.pitch_scale = pitch_multiplier
		
		hit_audio_player.play()
	
	# Update hit percentage
	if hit_percentage_bar:
		var hit_percentage = float(notes_hit) / float(max(1, notes_hit + notes_missed)) * 100.0
		hit_percentage_bar.value = hit_percentage
	
	DebugLogger.log_message("RhythmGameUI", "Note hit in lane %d! Total hits: %d" % [lane_index, notes_hit])

func _on_note_missed(lane_index: int):
	notes_missed += 1
	
	# Play miss sound
	if note_miss_sound and miss_audio_player:
		miss_audio_player.stream = note_miss_sound
		miss_audio_player.play()
	
	# Update hit percentage
	if hit_percentage_bar:
		var hit_percentage = float(notes_hit) / float(max(1, notes_hit + notes_missed)) * 100.0
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
	
	# Play completion sound
	if level_complete_sound and complete_audio_player:
		complete_audio_player.stream = level_complete_sound
		complete_audio_player.play()
	
	# Save progress
	has_played_today = true
	if score_percentage >= 60.0:  # Pass threshold
		current_level += 1
	
	# Emit signal and hide after delay
	game_finished.emit(score_percentage)
	
	await get_tree().create_timer(2.0).timeout
	visible = false
	
	# Clear all notes
	if lane_controller and lane_controller.has_method("clear_all_notes"):
		lane_controller.clear_all_notes()

func _cancel_game():
	game_active = false
	visible = false
	
	# Clear all notes
	if lane_controller and lane_controller.has_method("clear_all_notes"):
		lane_controller.clear_all_notes()
	
	game_cancelled.emit()
