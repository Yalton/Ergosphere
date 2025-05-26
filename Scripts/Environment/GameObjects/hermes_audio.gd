class_name HermesAudio
extends AudioStreamPlayer

## Debug settings
@export var enable_debug: bool = true
var module_name: String = "HermesAudio"

@export var enabled = true
## Sound that plays before any Hermes voice message
@export var intro_sound: AudioStream
## Collection of voice clips available to this Hermes
@export var voice_clips: Array[HermesVoiceClip] = []
## Delay in seconds before playing the intro ID on level start
@export var auto_play_delay: float = 10.0
## ID of the voice clip to play automatically at level start
@export var auto_play_id: String = "start"
## If true, will automatically display subtitles
@export var enable_subtitles: bool = true
## How long subtitles should remain displayed after their end time (in seconds)
@export var subtitle_overlap: float = 0.2

# Internal references
var intro_player: AudioStreamPlayer
var is_playing_sequence: bool = false
var queued_voice_clip: HermesVoiceClip = null
var current_voice_clip: HermesVoiceClip = null
var subtitle_timer: Timer
var player_ui_controller = null
var current_subtitle: String = ""
var last_subtitle_end_time: float = 0.0

func _ready() -> void:
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	
	# Create intro sound player
	intro_player = AudioStreamPlayer.new()
	intro_player.bus = bus  # Use same bus as this player
	intro_player.finished.connect(_on_intro_finished)
	add_child(intro_player)
	
	# Create subtitle timer
	subtitle_timer = Timer.new()
	subtitle_timer.wait_time = 0.1  # Check subtitle updates 10 times per second
	subtitle_timer.one_shot = false
	subtitle_timer.timeout.connect(_update_subtitles)
	add_child(subtitle_timer)
	
	# Connect our own finished signal
	finished.connect(_on_voice_finished)
	
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
	if is_playing_sequence:
		DebugLogger.warning(module_name, "Tried to play voice ID '" + id + "' but already playing a sequence")
		return false
	
	# Find the voice clip with the given ID
	var voice_clip = find_voice_clip(id)
	if not voice_clip:
		DebugLogger.error(module_name, "Voice clip with ID '" + id + "' not found")
		return false
	
	DebugLogger.debug(module_name, "Playing voice ID: " + id + " - " + voice_clip.description)
	
	# Start the sequence with intro sound
	is_playing_sequence = true
	queued_voice_clip = voice_clip
	
	if intro_sound:
		intro_player.stream = intro_sound
		intro_player.play()
		DebugLogger.debug(module_name, "Playing intro sound")
	else:
		# No intro sound, play voice directly
		_play_voice_clip(voice_clip)
	
	return true

func _on_intro_finished() -> void:
	if queued_voice_clip:
		_play_voice_clip(queued_voice_clip)

func _play_voice_clip(voice_clip: HermesVoiceClip) -> void:
	stream = voice_clip.audio_stream
	current_voice_clip = voice_clip
	play()
	
	# Start subtitle timer if we have subtitles and UI controller
	if enable_subtitles and voice_clip.subtitle_lines.size() > 0:
		# Try to find UI controller if we don't have one
		if not player_ui_controller:
			_find_player_ui_controller()
			
		if player_ui_controller:
			subtitle_timer.start()
			current_subtitle = ""
			last_subtitle_end_time = 0.0
			# Show initial subtitle if there's one at the beginning
			_update_subtitles()
		else:
			DebugLogger.warning(module_name, "Cannot show subtitles - UI controller not found")
	
	DebugLogger.debug(module_name, "Playing voice clip: " + voice_clip.id)

func _update_subtitles() -> void:
	if not current_voice_clip or not player_ui_controller:
		return
	
	# Get current playback position
	var current_time = get_playback_position()
	
	# Find active subtitle for current time
	var subtitle_text = current_voice_clip.get_active_subtitle(current_time)
	
	# Handle subtitle changes
	if subtitle_text != current_subtitle:
		if subtitle_text:
			# Show new subtitle without auto-hiding
			if player_ui_controller.has_method("show_persistent_message"):
				player_ui_controller.show_persistent_message(subtitle_text)
				DebugLogger.debug(module_name, "Showing persistent subtitle: " + subtitle_text)
			# Fall back to show_full_message with no auto-hide time
			elif player_ui_controller.has_method("show_full_message"):
				player_ui_controller.show_full_message(subtitle_text, -1) # -1 means don't auto-hide
				DebugLogger.debug(module_name, "Showing full subtitle: " + subtitle_text)
			else:
				player_ui_controller.show_message(subtitle_text)
				DebugLogger.debug(module_name, "Showing subtitle: " + subtitle_text)
		else:
			# No current subtitle active, check if we need to hide
			if current_subtitle != "" and player_ui_controller.has_method("hide_message"):
				player_ui_controller.hide_message()
				DebugLogger.debug(module_name, "Hiding subtitle")
		
		current_subtitle = subtitle_text
		
		# Store end time for current subtitle
		if subtitle_text:
			for line in current_voice_clip.subtitle_lines:
				if line.text == subtitle_text:
					last_subtitle_end_time = line.end_time
					break

func _on_voice_finished() -> void:
	DebugLogger.debug(module_name, "Voice sequence completed")
	
	# Hide any remaining subtitle
	if player_ui_controller and player_ui_controller.has_method("hide_message") and current_subtitle != "":
		player_ui_controller.hide_message()
		DebugLogger.debug(module_name, "Hiding final subtitle")
	
	is_playing_sequence = false
	queued_voice_clip = null
	current_voice_clip = null
	
	# Stop subtitle timer
	subtitle_timer.stop()
	current_subtitle = ""
	last_subtitle_end_time = 0.0

func find_voice_clip(id: String) -> HermesVoiceClip:
	for clip in voice_clips:
		if clip.id == id:
			return clip
	return null

func stop_voice() -> void:
	if intro_player.playing:
		intro_player.stop()
	
	if playing:
		stop()
	
	# Hide any displayed subtitle
	if player_ui_controller and player_ui_controller.has_method("hide_message") and current_subtitle != "":
		player_ui_controller.hide_message()
		DebugLogger.debug(module_name, "Hiding subtitle on stop")
	
	is_playing_sequence = false
	queued_voice_clip = null
	current_voice_clip = null
	subtitle_timer.stop()
	current_subtitle = ""
	last_subtitle_end_time = 0.0
	
	DebugLogger.debug(module_name, "Voice playback stopped")
