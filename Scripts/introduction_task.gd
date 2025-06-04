# introduction_task.gd
extends Node

## The Introduction task handler that guides players through exploring the station
## Plays voice lines as they enter new rooms and completes when all rooms are visited

@export var enable_debug: bool = true
var module_name: String = "IntroductionTask"

@export_group("Voice Settings")
## Hermes audio player for voice lines
@export var hermes_audio: HermesAudio
## Delay before playing room voice line after entering
@export var room_voice_delay: float = 2.0
## Delay before playing completion voice line
@export var completion_voice_delay: float = 1.0

@export_group("Task Settings")
## Task aware component to handle task completion
@export var task_aware_component: TaskAwareComponent
## The three tasks to assign after intro completion
@export var follow_up_task_ids: Array[String] = ["check_systems", "eat_breakfast", "calibrate_equipment"]

@export_group("Room Requirements")
## Rooms that must be visited to complete the introduction
@export var required_rooms: Array[String] = ["server_room", "stor_room", "oxy_room", "hab_room", "eng_room", "obs_room"]
@export var player_detection: PlayerDetection

# Track which rooms have been visited
var visited_rooms: Dictionary = {}
var rooms_with_played_audio: Dictionary = {}
var is_intro_complete: bool = false

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Validate components
	if not hermes_audio:
		DebugLogger.error(module_name, "No HermesAudio assigned!")
		return
		
	if not task_aware_component:
		task_aware_component = get_node_or_null("TaskAwareComponent")
		if not task_aware_component:
			DebugLogger.error(module_name, "No TaskAwareComponent found!")
			return
	
	# Find player detection node
	#player_detection = get_node_or_null("/root/Main/PlayerDetection")
	#if not player_detection:
		#DebugLogger.error(module_name, "PlayerDetection node not found at expected path!")
		#return
	
	player_detection.player_in_room.connect(_on_player_in_room)
	# Connect to player detection signals
	#for child in player_detection.get_children():
		#if child is PlayerScanner:
			#child.player_in_room.connect(_on_player_in_room)
			#DebugLogger.debug(module_name, "Connected to PlayerScanner: " + child.room_id)
	
	# Initialize room tracking
	for room in required_rooms:
		visited_rooms[room] = false
		rooms_with_played_audio[room] = false
	
	# Start the introduction after a short delay
	var start_timer = get_tree().create_timer(2.0)
	start_timer.timeout.connect(_start_introduction)
	
	DebugLogger.info(module_name, "Introduction task initialized with " + str(required_rooms.size()) + " required rooms")

func _start_introduction() -> void:
	DebugLogger.info(module_name, "Starting introduction sequence")
	
	# Play the initial intro message
	if hermes_audio:
		hermes_audio.play_voice_by_id("start")
	else:
		DebugLogger.error(module_name, "Cannot play intro - no HermesAudio!")

func _on_player_in_room(room_id: String) -> void:
	# Skip if intro is already complete
	if is_intro_complete:
		return
	
	# Check if this is a required room
	if not room_id in required_rooms:
		DebugLogger.debug(module_name, "Player entered non-required room: " + room_id)
		return
	
	# Check if we've already visited this room
	if visited_rooms[room_id]:
		return
	
	# Mark room as visited
	visited_rooms[room_id] = true
	DebugLogger.info(module_name, "Player visited new room: " + room_id)
	
	# Play room-specific voice line after delay
	if not rooms_with_played_audio[room_id]:
		_queue_room_voice_line(room_id)
	
	# Check if all rooms have been visited
	_check_completion()

func _queue_room_voice_line(room_id: String) -> void:
	# Don't play if we've already played audio for this room
	if rooms_with_played_audio[room_id]:
		return
		
	var timer = get_tree().create_timer(room_voice_delay)
	timer.timeout.connect(_play_room_voice_line.bind(room_id))

func _play_room_voice_line(room_id: String) -> void:
	# Double-check we haven't played this already (in case of rapid room switching)
	if rooms_with_played_audio[room_id]:
		return
		
	rooms_with_played_audio[room_id] = true
	
	# Map room ID to voice clip ID
	var voice_clip_id = room_id
	
	DebugLogger.debug(module_name, "Playing voice line for room: " + room_id + " (clip: " + voice_clip_id + ")")
	
	if hermes_audio:
		hermes_audio.play_voice_by_id(voice_clip_id)
	else:
		DebugLogger.error(module_name, "Cannot play room voice line - no HermesAudio!")

func _check_completion() -> void:
	# Count visited rooms
	var visited_count = 0
	for room in required_rooms:
		if visited_rooms[room]:
			visited_count += 1
	
	DebugLogger.debug(module_name, "Visited " + str(visited_count) + " of " + str(required_rooms.size()) + " required rooms")
	
	# Check if all required rooms have been visited
	var all_visited = true
	for room in required_rooms:
		if not visited_rooms[room]:
			all_visited = false
			break
	
	if all_visited and not is_intro_complete:
		_complete_introduction()

func _complete_introduction() -> void:
	is_intro_complete = true
	DebugLogger.info(module_name, "Introduction complete - all rooms visited!")
	
	# Play completion voice line after delay
	var timer = get_tree().create_timer(completion_voice_delay)
	timer.timeout.connect(_play_completion_voice)
	
	# Complete the introduction task
	if task_aware_component:
		task_aware_component.complete_task()
	
	# Assign follow-up tasks
	_assign_follow_up_tasks()

func _play_completion_voice() -> void:
	if hermes_audio:
		hermes_audio.play_voice_by_id("tour_complete")
	else:
		DebugLogger.error(module_name, "Cannot play completion voice line - no HermesAudio!")

func _assign_follow_up_tasks() -> void:
	if not GameManager or not GameManager.task_manager:
		DebugLogger.error(module_name, "Cannot assign follow-up tasks - GameManager/TaskManager not found!")
		return
	
	DebugLogger.info(module_name, "Assigning follow-up tasks: " + str(follow_up_task_ids))
	
	# In a real implementation, you'd want to add these tasks to today's task list
	# For now, we'll just log that they should be assigned
	for task_id in follow_up_task_ids:
		DebugLogger.debug(module_name, "Would assign task: " + task_id)
	
	# Note: The actual task assignment would need to be implemented in TaskManager
	# as it currently doesn't have a method to dynamically add tasks mid-day

# Helper function to get progress for UI display
func get_progress() -> Dictionary:
	var visited_count = 0
	for room in required_rooms:
		if visited_rooms[room]:
			visited_count += 1
	
	return {
		"visited": visited_count,
		"total": required_rooms.size(),
		"percentage": float(visited_count) / float(required_rooms.size()) * 100.0,
		"remaining_rooms": _get_remaining_rooms()
	}

func _get_remaining_rooms() -> Array[String]:
	var remaining: Array[String] = []
	for room in required_rooms:
		if not visited_rooms[room]:
			remaining.append(room)
	return remaining

# Debug function to manually mark a room as visited
func debug_visit_room(room_id: String) -> void:
	if not enable_debug:
		return
		
	DebugLogger.debug(module_name, "Debug: Marking room as visited: " + room_id)
	_on_player_in_room(room_id)

# Debug function to reset the introduction
func debug_reset() -> void:
	if not enable_debug:
		return
		
	DebugLogger.debug(module_name, "Debug: Resetting introduction task")
	is_intro_complete = false
	
	for room in required_rooms:
		visited_rooms[room] = false
		rooms_with_played_audio[room] = false
