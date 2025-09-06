class_name HermesAudio
extends Node

## Main Hermes audio controller that plays voice clips with synchronized subtitles
## Handles audio playback and subtitle timing

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

## Volume adjustment for voice clips in dB
@export var voice_volume_db: float = 0.0

## Audio bus to use for voice playback
@export var audio_bus: String = "Voice"

# Internal state
var current_voice_clip: HermesVoiceClip = null
var player_ui_controller = null
var current_subtitle: String = ""
var played_voice_ids: Array[String] = []
var current_subtitle_index: int = 0
var subtitle_timer: Timer
var audio_player: AudioStreamPlayer
var is_playing: bool = false
var playback_start_time: float = 0.0

func _ready() -> void:
	var module_name = "HermesAudio"
	DebugLogger.register_module(module_name, true)
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = audio_bus
	audio_player.volume_db = voice_volume_db
	audio_player.finished.connect(_on_audio_finished)
	add_child(audio_player)
	
	# Create subtitle timer
	subtitle_timer = Timer.new()
	subtitle_timer.one_shot = true
	subtitle_timer.timeout.connect(_check_next_subtitle)
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
	
	# Update subtitle display based on current playback time
	if is_playing and current_voice_clip and enable_subtitles:
		_update_subtitle_display()

func _find_player_ui_controller() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player:
			player_ui_controller = player.ui_controller
			DebugLogger.debug("HermesAudio", "Found player UI controller")

func play_voice_by_id(id: String) -> bool:
	if !enabled: 
		return false
	
	if is_playing:
		DebugLogger.warning("HermesAudio", "Interrupting current voice to play ID '" + id + "'")
		stop_voice()
	
	# Find the voice clip with the given ID
	var voice_clip = find_voice_clip(id)
	if not voice_clip:
		DebugLogger.error("HermesAudio", "Voice clip with ID '" + id + "' not found")
		return false
	
	# Check if we've already played this and if it's repeatable
	if id in played_voice_ids and not voice_clip.is_repeatable:
		DebugLogger.debug("HermesAudio", "Voice clip already played and not repeatable: " + id)
		return false
	
	# Check if audio stream exists
	if not voice_clip.audio_stream:
		DebugLogger.error("HermesAudio", "Voice clip '" + id + "' has no audio stream")
		return false
	
	played_voice_ids.append(id)
	DebugLogger.debug("HermesAudio", "Playing voice ID: " + id + " - " + voice_clip.description)
	
	_play_voice_clip(voice_clip)
	return true

func _play_voice_clip(voice_clip: HermesVoiceClip) -> void:
	current_voice_clip = voice_clip
	current_subtitle_index = 0
	is_playing = true
	playback_start_time = Time.get_ticks_msec() / 1000.0
	
	# Play the audio
	audio_player.stream = voice_clip.audio_stream
	audio_player.play()
	
	# Start subtitle management if enabled
	if enable_subtitles and voice_clip.subtitle_lines.size() > 0:
		if not player_ui_controller:
			_find_player_ui_controller()
		
		# Initialize subtitle display
		current_subtitle = ""
		_update_subtitle_display()
	
	DebugLogger.debug("HermesAudio", "Playing voice clip: " + voice_clip.id)

func _update_subtitle_display() -> void:
	if not current_voice_clip or not player_ui_controller:
		return
	
	var current_time = (Time.get_ticks_msec() / 1000.0) - playback_start_time
	
	# Find which subtitle should be showing at this time
	var subtitle_to_show: HermesSubtitleLine = null
	for subtitle_line in current_voice_clip.subtitle_lines:
		if current_time >= subtitle_line.start_time and current_time < subtitle_line.end_time:
			subtitle_to_show = subtitle_line
			break
	
	# Update subtitle if it changed
	if subtitle_to_show:
		if current_subtitle != subtitle_to_show.text:
			current_subtitle = subtitle_to_show.text
			_show_subtitle(subtitle_to_show.text)
	else:
		# No subtitle should be showing
		if current_subtitle != "":
			current_subtitle = ""
			_hide_subtitle()

func _show_subtitle(text: String) -> void:
	if not player_ui_controller:
		return
	
	if player_ui_controller.has_method("show_persistent_message"):
		player_ui_controller.show_persistent_message(speaker_name, text)
	elif player_ui_controller.has_method("show_full_message"):
		player_ui_controller.show_full_message(speaker_name, text, -1)
	else:
		player_ui_controller.show_message(speaker_name, text)
	
	DebugLogger.debug("HermesAudio", "Showing subtitle: " + text)

func _hide_subtitle() -> void:
	if not player_ui_controller:
		return
	
	if player_ui_controller.has_method("hide_message"):
		player_ui_controller.hide_message()
		DebugLogger.debug("HermesAudio", "Hiding subtitle")

func _check_next_subtitle() -> void:
	# This is called periodically to update subtitle display
	if is_playing:
		_update_subtitle_display()
		# Schedule next check
		subtitle_timer.wait_time = 0.1  # Check every 100ms
		subtitle_timer.start()

func _on_audio_finished() -> void:
	DebugLogger.debug("HermesAudio", "Audio playback finished")
	
	# Hide any remaining subtitle
	if player_ui_controller and current_subtitle != "":
		_hide_subtitle()
	
	is_playing = false
	current_voice_clip = null
	current_subtitle = ""
	current_subtitle_index = 0
	subtitle_timer.stop()

func find_voice_clip(id: String) -> HermesVoiceClip:
	for clip in voice_clips:
		if clip.id == id:
			return clip
	return null

func stop_voice() -> void:
	# Stop audio playback
	if audio_player.playing:
		audio_player.stop()
	
	# Stop subtitle timer
	subtitle_timer.stop()
	
	# Hide any displayed subtitle
	if player_ui_controller and current_subtitle != "":
		_hide_subtitle()
	
	is_playing = false
	current_voice_clip = null
	current_subtitle = ""
	current_subtitle_index = 0
	
	DebugLogger.debug("HermesAudio", "Voice playback stopped")

func _on_task_completed(task_id: String) -> void:
	# Look for a voice clip with matching ID
	var voice_clip = find_voice_clip(task_id)
	if not voice_clip:
		DebugLogger.debug("HermesAudio", "No voice clip found for completed task: " + task_id)
		return
	
	var success = play_voice_by_id(task_id)
	DebugLogger.debug("HermesAudio", "Task completed trigger - playing voice: " + task_id + " (success: " + str(success) + ")")

func is_playing_voice() -> bool:
	return is_playing

func get_current_voice_id() -> String:
	if current_voice_clip:
		return current_voice_clip.id
	return ""
