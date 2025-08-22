# SleepStatsScreen.gd
extends Control
class_name SleepStatsScreen

signal stats_complete

@export var enable_debug: bool = true
var module_name: String = "SleepStatsScreen"

## The grid container with 8 labels (2 columns, 4 rows) - removed score row
@export var stats_grid: GridContainer

## Typing speed for filling each label
@export var letter_time: float = 0.05

## Pause between each label being filled
@export var label_pause_time: float = 0.3

## How long to display completed stats
@export var display_duration: float = 3.0

## Audio for typing effect
@export var typing_sound: AudioStream

## Day-specific messages
@export var day_messages: Array[String] = [
	"INITIAL ASSESSMENT",
	"ANOMALY PATTERNS", 
	"BEHAVIORAL ANALYSIS",
	"PROFILE UPDATED",
	"FINAL EVALUATION"
]

# Internal state
var grid_labels: Array[Label] = []
var stats_data: Array[String] = []
var current_label_index: int = 0
var current_char_index: int = 0
var typing_timer: Timer
var pause_timer: Timer

var is_typing: bool = false
var stats_day_number: int = -1  # Store the day we're showing stats for

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Initially hidden and high z-index
	hide()
	z_index = 1000
	
	# Get grid labels
	_setup_grid_labels()
	
	# Setup timers
	_setup_timers()

func _setup_grid_labels() -> void:
	if not stats_grid:
		DebugLogger.error(module_name, "No stats_grid assigned!")
		return
	
	# Get all label children from the grid
	grid_labels.clear()
	for child in stats_grid.get_children():
		if child is Label:
			grid_labels.append(child)
			child.text = ""  # Start empty
	
	DebugLogger.debug(module_name, "Found %d labels in grid" % grid_labels.size())

func _setup_timers() -> void:
	# Letter typing timer
	typing_timer = Timer.new()
	typing_timer.one_shot = true
	typing_timer.timeout.connect(_type_next_character)
	add_child(typing_timer)
	
	# Pause between labels timer
	pause_timer = Timer.new()
	pause_timer.one_shot = true
	pause_timer.timeout.connect(_start_next_label)
	add_child(pause_timer)

## Show stats for the specified day
func show_stats_for_day(day_number: int) -> void:
	stats_day_number = day_number
	
	# Gather stats data
	_gather_stats_data(day_number)
	
	# Clear all labels
	_clear_all_labels()
	
	# Show the screen
	show()
	
	# Start typing the first label
	current_label_index = 0
	current_char_index = 0
	is_typing = true
	_start_typing_current_label()
	
	DebugLogger.info(module_name, "Showing stats for day %d" % day_number)

## Show stats for the day that just ended (before day increment)
func show_stats_for_completed_day() -> void:
	# Get the day that just ended (current day - 1 since it was already incremented)
	var completed_day = GameManager.get_current_day() - 1
	
	# Clamp to valid range
	if completed_day < 1:
		completed_day = 1
	
	show_stats_for_day(completed_day)

func _gather_stats_data(day_number: int) -> void:
	stats_data.clear()
	
	# Gather data
	var sanity = _get_sanity_level()
	var sanity_text = _get_sanity_text(sanity)
	var tasks_completed = _get_completed_tasks()
	var day_message = _get_day_message(day_number)
	
	# Build the stats array in order (label pairs) - removed score
	stats_data.append("DAY")
	stats_data.append(str(day_number))
	stats_data.append("SANITY LEVEL")
	stats_data.append(sanity_text)
	stats_data.append("TASKS COMPLETED")
	stats_data.append(str(tasks_completed))
	stats_data.append("STATUS")
	stats_data.append(day_message)
	
	DebugLogger.debug(module_name, "Stats data: %s" % str(stats_data))

func _get_sanity_level() -> int:
	var player = CommonUtils.get_player()
	if player:
		var insanity_comp = null
		for child in player.get_children():
			if child.has_method("add_insanity"):
				insanity_comp = child
				break
		
		if insanity_comp:
			return int(100 - insanity_comp.current_insanity)
	
	return 100  # Default

func _get_sanity_text(sanity: int) -> String:
	if sanity > 75:
		return "STABLE"
	elif sanity > 50:
		return "IMPAIRED"
	elif sanity > 25:
		return "UNSTABLE"
	else:
		return "CRITICAL"

func _get_completed_tasks() -> int:
	if GameManager and GameManager.task_manager:
		# Get the completed tasks count from task_manager
		# This should represent tasks completed during the day that just ended
		return GameManager.task_manager.completed_tasks.size()
	
	return 0

func _get_day_message(day_number: int) -> String:
	var day_index = day_number - 1
	if day_index >= 0 and day_index < day_messages.size():
		return day_messages[day_index]
	return "ANALYSIS COMPLETE"

func _clear_all_labels() -> void:
	for label in grid_labels:
		label.text = ""

func _start_typing_current_label() -> void:
	if current_label_index >= grid_labels.size() or current_label_index >= stats_data.size():
		_finish_all_typing()
		return
	
	current_char_index = 0
	DebugLogger.debug(module_name, "Starting label %d: '%s'" % [current_label_index, stats_data[current_label_index]])
	_type_next_character()

func _type_next_character() -> void:
	if not is_typing:
		return
	
	var current_text = stats_data[current_label_index]
	var current_label = grid_labels[current_label_index]
	
	if current_char_index < current_text.length():
		# Add next character
		current_label.text = current_text.substr(0, current_char_index + 1)
		current_char_index += 1
		
		# Play typing sound
		if typing_sound and current_char_index % 3 == 0:  # Every 3rd character
			Audio.play_sound_with_random_pitch(typing_sound, 0.95, 1.05, true, 0.0, "SFX")
		
		# Schedule next character
		typing_timer.start(letter_time)
	else:
		# Current label complete, move to next
		current_label_index += 1
		
		if current_label_index < grid_labels.size() and current_label_index < stats_data.size():
			# Pause before next label
			pause_timer.start(label_pause_time)
		else:
			# All labels complete
			_finish_all_typing()

func _start_next_label() -> void:
	_start_typing_current_label()

func _finish_all_typing() -> void:
	is_typing = false
	DebugLogger.debug(module_name, "All typing complete, displaying for %fs" % display_duration)
	
	# Wait for display duration then signal completion
	var timer = get_tree().create_timer(display_duration)
	timer.timeout.connect(_finish_stats_display)

func _finish_stats_display() -> void:
	DebugLogger.info(module_name, "Stats display complete")
	
	# Hide screen
	hide()
	
	# Clear labels
	_clear_all_labels()
	
	# Reset stored day number
	stats_day_number = -1
	
	# Signal completion
	stats_complete.emit()

## Force skip the typing
func skip_stats() -> void:
	if is_typing:
		is_typing = false
		typing_timer.stop()
		pause_timer.stop()
		
		# Fill all remaining labels immediately
		for i in range(current_label_index, min(grid_labels.size(), stats_data.size())):
			grid_labels[i].text = stats_data[i]
	
	_finish_stats_display()

## Get current stats data for external use
func get_current_stats() -> Array[String]:
	return stats_data
