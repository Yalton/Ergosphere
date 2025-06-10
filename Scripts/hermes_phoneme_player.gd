class_name HermesPhonemePlayer
extends Node

## Plays overlapping phoneme sounds to create a continuous voice-like effect
## Uses multiple AudioStreamPlayers for smooth transitions and better coverage

@export var enable_debug: bool = true
var module_name: String = "HermesPhonemePlayer"

## Collection of short phoneme audio clips (roughly 0.1 seconds each)
@export var phoneme_sounds: Array[AudioStream] = []

## Notification sound played at the start of voice lines
@export var notification_sound: AudioStream

## Number of simultaneous audio players for overlapping phonemes
@export var audio_player_count: int = 4

## Pitch variation range for phonemes
@export var pitch_min: float = 0.8
@export var pitch_max: float = 1.2

## Volume variation range for phonemes  
@export var volume_min: float = 0.6
@export var volume_max: float = 0.9

## Base volume for all phonemes
@export var base_volume_db: float = -6.0

## Overlap factor - how much phonemes overlap (0.0 = no overlap, 1.0 = full overlap)
@export var phoneme_overlap: float = 0.3

## Fade in/out duration for each phoneme
@export var fade_duration: float = 0.02

## Phoneme density based on text complexity
@export var min_phonemes_per_word: float = 0.8
@export var max_phonemes_per_word: float = 1.5

## Padding at start and end of each subtitle line (seconds)
@export var subtitle_padding: float = 0.1

# Internal state
var audio_players: Array[AudioStreamPlayer] = []
var notification_player: AudioStreamPlayer
var current_sequence_timer: Timer
var is_playing_sequence: bool = false
var sequence_start_time: float = 0.0
var sequence_duration: float = 0.0
var scheduled_phonemes: Array[PhonemeData] = []
var next_phoneme_index: int = 0

class PhonemeData:
	var sound: AudioStream
	var pitch: float
	var volume: float
	var start_time: float
	var player_index: int

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Create multiple audio players for overlapping sounds
	for i in audio_player_count:
		var player = AudioStreamPlayer.new()
		player.bus = "Voice"  # Assuming you have a Voice audio bus
		add_child(player)
		audio_players.append(player)
	
	# Create notification player
	notification_player = AudioStreamPlayer.new()
	notification_player.bus = "Voice"
	add_child(notification_player)
	
	# Create timer for sequence updates
	current_sequence_timer = Timer.new()
	current_sequence_timer.wait_time = 0.05  # Update every 50ms
	current_sequence_timer.timeout.connect(_update_sequence)
	add_child(current_sequence_timer)

## Generate and play a phoneme sequence for the given subtitle line
func play_phoneme_sequence(subtitle_line: HermesSubtitleLine, with_notification: bool = false) -> void:
	if phoneme_sounds.is_empty():
		DebugLogger.error(module_name, "No phoneme sounds available!")
		return
	
	# Stop any currently playing sequence
	if is_playing_sequence:
		stop_sequence()
	
	# Play notification sound if requested
	if with_notification and notification_sound and notification_player:
		notification_player.stream = notification_sound
		notification_player.volume_db = base_volume_db
		notification_player.play()
		DebugLogger.debug(module_name, "Playing notification sound")
		
		# Delay phoneme start by 0.5 seconds after notification
		var notification_delay = 0.5
		var delay_timer = get_tree().create_timer(notification_delay)
		delay_timer.timeout.connect(func(): _start_phoneme_sequence(subtitle_line))
	else:
		_start_phoneme_sequence(subtitle_line)

func _start_phoneme_sequence(subtitle_line: HermesSubtitleLine) -> void:
	var duration = subtitle_line.end_time - subtitle_line.start_time
	var text = subtitle_line.text.strip_edges()
	var words = text.split(" ", false)
	var word_count = words.size()
	
	# Adjust phoneme density based on text characteristics
	var avg_word_length = 0.0
	for word in words:
		avg_word_length += word.length()
	avg_word_length /= max(word_count, 1)
	
	# More complex words = more phonemes
	var complexity_factor = clamp(avg_word_length / 6.0, 0.5, 1.5)
	
	DebugLogger.debug(module_name, "Generating phonemes for: '" + text + "' (" + str(duration) + "s, " + str(word_count) + " words, complexity: " + str(complexity_factor) + ")")
	
	# Generate the phoneme sequence
	scheduled_phonemes = _generate_phoneme_sequence(duration, word_count, complexity_factor)
	next_phoneme_index = 0
	is_playing_sequence = true
	sequence_start_time = Time.get_ticks_msec() / 1000.0
	sequence_duration = duration
	
	# Start the update timer
	current_sequence_timer.start()

## Generate a sequence of phonemes that covers the entire duration
func _generate_phoneme_sequence(duration: float, word_count: int, complexity: float) -> Array[PhonemeData]:
	var sequence: Array[PhonemeData] = []
	
	if word_count == 0:
		word_count = 1
	
	# Calculate phoneme count based on words and complexity
	var base_phonemes = word_count * lerp(min_phonemes_per_word, max_phonemes_per_word, complexity)
	var phoneme_count = int(base_phonemes)
	phoneme_count = clamp(phoneme_count, 3, int(duration * 8))  # Max 8 phonemes per second
	
	# Adjust duration for padding
	var effective_duration = duration - (subtitle_padding * 2)
	if effective_duration <= 0:
		effective_duration = duration * 0.8  # Fallback if padding is too large
	
	# Calculate timing with padding
	var phoneme_spacing = effective_duration / max(phoneme_count - 1, 1)
	
	var current_time = subtitle_padding  # Start after padding
	var player_index = 0
	
	for i in phoneme_count:
		var phoneme_data = PhonemeData.new()
		
		# Select random phoneme with variation
		phoneme_data.sound = phoneme_sounds[randi() % phoneme_sounds.size()]
		
		# Vary pitch more for emphasis (simulate intonation)
		var emphasis = sin(i * PI / phoneme_count) * 0.2  # Wave pattern for natural speech
		phoneme_data.pitch = randf_range(pitch_min, pitch_max) + emphasis
		
		# Vary volume for natural rhythm
		var volume_variation = sin(i * PI * 2.0 / phoneme_count) * 0.1
		phoneme_data.volume = randf_range(volume_min, volume_max) + volume_variation
		
		phoneme_data.start_time = current_time
		phoneme_data.player_index = player_index
		
		sequence.append(phoneme_data)
		
		# Advance time and player index
		current_time += phoneme_spacing
		player_index = (player_index + 1) % audio_player_count
	
	DebugLogger.debug(module_name, "Generated " + str(phoneme_count) + " phonemes over " + str(duration) + "s (spacing: " + str(phoneme_spacing) + "s)")
	return sequence

## Update the phoneme sequence playback
func _update_sequence() -> void:
	if not is_playing_sequence:
		return
	
	var current_time = (Time.get_ticks_msec() / 1000.0) - sequence_start_time
	
	# Check if sequence is complete
	if current_time >= sequence_duration:
		_finish_sequence()
		return
	
	# Play any phonemes that should start now
	while next_phoneme_index < scheduled_phonemes.size():
		var phoneme = scheduled_phonemes[next_phoneme_index]
		
		if phoneme.start_time <= current_time:
			_play_phoneme(phoneme)
			next_phoneme_index += 1
		else:
			break

## Play a single phoneme with fade in/out
func _play_phoneme(phoneme: PhonemeData) -> void:
	var player = audio_players[phoneme.player_index]
	
	# Don't interrupt if still playing (allows overlap)
	if player.playing and player.get_playback_position() < 0.05:
		return
	
	# Set up audio properties
	player.stream = phoneme.sound
	player.pitch_scale = phoneme.pitch
	player.volume_db = base_volume_db + linear_to_db(phoneme.volume)
	
	# Play with fade in
	player.play()
	
	# Create tween for fade in/out if needed
	if fade_duration > 0:
		var tween = get_tree().create_tween()
		var original_volume = player.volume_db
		
		# Fade in
		player.volume_db = original_volume - 20
		tween.tween_property(player, "volume_db", original_volume, fade_duration)
		
		# Fade out before end
		if player.stream:
			var fade_out_time = player.stream.get_length() - fade_duration
			if fade_out_time > fade_duration:
				tween.tween_interval(fade_out_time - fade_duration)
				tween.tween_property(player, "volume_db", original_volume - 20, fade_duration)

## Finish the current phoneme sequence
func _finish_sequence() -> void:
	is_playing_sequence = false
	scheduled_phonemes.clear()
	next_phoneme_index = 0
	current_sequence_timer.stop()
	
	DebugLogger.debug(module_name, "Phoneme sequence completed")

## Stop the current phoneme sequence
func stop_sequence() -> void:
	current_sequence_timer.stop()
	
	# Stop all audio players with fade out
	for player in audio_players:
		if player.playing:
			var tween = get_tree().create_tween()
			tween.tween_property(player, "volume_db", -40, 0.1)
			tween.tween_callback(player.stop)
	
	_finish_sequence()
	
	DebugLogger.debug(module_name, "Phoneme sequence stopped")
