class_name HermesAudio
extends HermesPhonemePlayer

## Main Hermes audio controller that plays phoneme sequences instead of voice files
## Handles subtitle timing and phoneme audio synchronization

## Enable or disable this Hermes instance
@export var enabled = true
## Collection of voice clips available to this Hermes
@export var voice_clips: Array[HermesVoiceClip] = []
## Delay in seconds before playing the intro ID on level start
@export var auto_play_delay: float = 10.0
## ID of the voice clip to play automatically at level start
@export var auto_play_id: String = "start"
## If true, will automatically display subtitles
@export var enable_subtitles: bool = true
## Name displayed before subtitles
@export var speaker_name: String = "[Hermes]:"

# Internal state
var queued_voice_clip: HermesVoiceClip = null
var current_voice_clip: HermesVoiceClip = null
var player_ui_controller = null
var current_subtitle: String = ""
var played_voice_ids: Array[String] = []
var current_subtitle_index: int = 0
var subtitle_timer: Timer

func _ready() -> void:
	super._ready()
	module_name = "HermesAudio"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Create subtitle timer
	subtitle_timer = Timer.new()
	subtitle_timer.one_shot = true
	subtitle_timer.timeout.connect(_on_subtitle_line_finished)
	add_child(subtitle_timer)
	
	# Connect to task completion signal
	if GameManager and GameManager.task_manager:
		GameManager.task_manager.task_completed.connect(_on_task_completed)
		DebugLogger.debug(module_name, "Connected to TaskManager task_completed signal")
	
	# Set up auto-play if configured
	if auto_play_id and auto_play_delay > 0 and enabled:
		DebugLogger.debug(module_name, "Will auto-play voice ID '" + auto_play_id + "' after " + str(auto_play_delay) + " seconds")
		var timer = get_tree().create_timer(auto_play_delay)
		timer.timeout.connect(func(): play_voice_by_id(auto_play_id))

func _process(_delta: float) -> void:
	# Find player UI controller if we don't have one already
	if not player_ui_controller and enable_subtitles:
		_find_player_ui_controller()

func _find_player_ui_controller() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player:
			player_ui_controller = player.ui_controller
			DebugLogger.debug(module_name, "Found player UI controller")

func play_voice_by_id(id: String) -> bool:
	if !enabled: 
		return false
	
	if is_playing_sequence:
		DebugLogger.warning(module_name, "Interrupting current voice to play ID '" + id + "'")
		stop_voice()
	
	# Find the voice clip with the given ID
	var voice_clip = find_voice_clip(id)
	if not voice_clip:
		DebugLogger.error(module_name, "Voice clip with ID '" + id + "' not found")
		return false
	
	# Check if we've already played this and if it's repeatable
	if id in played_voice_ids and not voice_clip.is_repeatable:
		DebugLogger.debug(module_name, "Voice clip already played and not repeatable: " + id)
		return false
	
	played_voice_ids.append(id)
	DebugLogger.debug(module_name, "Playing voice ID: " + id + " - " + voice_clip.description)
	
	_play_voice_clip(voice_clip)
	return true

func _play_voice_clip(voice_clip: HermesVoiceClip) -> void:
	current_voice_clip = voice_clip
	current_subtitle_index = 0
	is_playing_sequence = true
	
	# Start subtitle management if we have subtitles and UI controller
	if enable_subtitles and voice_clip.subtitle_lines.size() > 0:
		if not player_ui_controller:
			_find_player_ui_controller()
			
		if player_ui_controller:
			current_subtitle = ""
			_start_next_subtitle_line()
		else:
			DebugLogger.warning(module_name, "Cannot show subtitles - UI controller not found")
			# Still play phonemes even without UI
			_play_phonemes_without_subtitles()
	else:
		# No subtitles, create a basic line based on the description
		_play_phonemes_without_subtitles()
	
	DebugLogger.debug(module_name, "Playing voice clip: " + voice_clip.id)

func _play_phonemes_without_subtitles() -> void:
	# Create a dummy subtitle line for phoneme timing
	var dummy_line = HermesSubtitleLine.new()
	dummy_line.start_time = 0.0
	dummy_line.end_time = 2.0  # Default 2 second duration
	dummy_line.text = current_voice_clip.description if current_voice_clip else "..."
	
	# Play with notification since this is the start
	play_phoneme_sequence(dummy_line, true)
	
	# Schedule finish (with notification delay)
	var total_time = dummy_line.end_time
	if notification_sound:
		total_time += 0.5  # Account for notification delay
	var timer = get_tree().create_timer(total_time)
	timer.timeout.connect(_finish_voice_sequence)

func _start_next_subtitle_line() -> void:
	if current_subtitle_index >= current_voice_clip.subtitle_lines.size():
		# All subtitle lines processed
		_finish_voice_sequence()
		return
	
	var subtitle_line = current_voice_clip.subtitle_lines[current_subtitle_index]
	current_subtitle = subtitle_line.text
	
	# Only play notification on the very first line
	var with_notification = (current_subtitle_index == 0)
	
	# Delay subtitle display if notification is playing
	if with_notification and notification_sound:
		DebugLogger.debug(module_name, "Delaying subtitle for notification")
		var delay_timer = get_tree().create_timer(0.5)
		delay_timer.timeout.connect(func(): _show_subtitle_and_play_phonemes(subtitle_line, with_notification))
	else:
		_show_subtitle_and_play_phonemes(subtitle_line, with_notification)

func _show_subtitle_and_play_phonemes(subtitle_line: HermesSubtitleLine, with_notification: bool) -> void:
	# Show the subtitle
	if player_ui_controller:
		if player_ui_controller.has_method("show_persistent_message"):
			player_ui_controller.show_persistent_message(speaker_name, subtitle_line.text)
		elif player_ui_controller.has_method("show_full_message"):
			player_ui_controller.show_full_message(speaker_name, subtitle_line.text, -1)
		else:
			player_ui_controller.show_message(speaker_name, subtitle_line.text)
		
		DebugLogger.debug(module_name, "Showing subtitle: " + subtitle_line.text)
	
	# Play phonemes for this subtitle line
	play_phoneme_sequence(subtitle_line, with_notification)
	
	# Schedule next subtitle line
	var line_duration = subtitle_line.end_time - subtitle_line.start_time
	# Add notification delay only for first line
	if with_notification and notification_sound:
		line_duration += 0.5  # Account for notification delay
	subtitle_timer.wait_time = line_duration
	subtitle_timer.start()

func _on_subtitle_line_finished() -> void:
	# Stop any remaining phonemes from previous line
	stop_sequence()
	
	# Hide current subtitle
	if player_ui_controller and player_ui_controller.has_method("hide_message") and current_subtitle != "":
		player_ui_controller.hide_message()
		DebugLogger.debug(module_name, "Hiding subtitle")
	
	current_subtitle_index += 1
	
	# Small gap between subtitle lines for natural pacing
	var gap_timer = get_tree().create_timer(0.1)
	gap_timer.timeout.connect(_start_next_subtitle_line)

func _finish_voice_sequence() -> void:
	DebugLogger.debug(module_name, "Voice sequence completed")
	
	# Stop phoneme player
	stop_sequence()
	
	# Stop subtitle timer
	subtitle_timer.stop()
	
	# Hide any remaining subtitle
	if player_ui_controller and player_ui_controller.has_method("hide_message") and current_subtitle != "":
		player_ui_controller.hide_message()
		DebugLogger.debug(module_name, "Hiding final subtitle")
	
	is_playing_sequence = false
	current_voice_clip = null
	current_subtitle = ""
	current_subtitle_index = 0

func find_voice_clip(id: String) -> HermesVoiceClip:
	for clip in voice_clips:
		if clip.id == id:
			return clip
	return null

func stop_voice() -> void:
	# Stop phoneme sequence
	stop_sequence()
	
	# Stop subtitle timer
	subtitle_timer.stop()
	
	# Hide any displayed subtitle
	if player_ui_controller and player_ui_controller.has_method("hide_message") and current_subtitle != "":
		player_ui_controller.hide_message()
		DebugLogger.debug(module_name, "Hiding subtitle on stop")
	
	is_playing_sequence = false
	current_voice_clip = null
	current_subtitle = ""
	current_subtitle_index = 0
	
	DebugLogger.debug(module_name, "Voice playback stopped")

func _on_task_completed(task_id: String) -> void:
	# Look for a voice clip with matching ID
	var voice_clip = find_voice_clip(task_id)
	if not voice_clip:
		DebugLogger.debug(module_name, "No voice clip found for completed task: " + task_id)
		return
	
	var success = play_voice_by_id(task_id)
	DebugLogger.debug(module_name, "Task completed trigger - playing voice: " + task_id + " (success: " + str(success) + ")")
