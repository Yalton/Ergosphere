# Enhanced Audio Singleton with Pitch, Volume, and Bus Control
# Based on Bryce Dixon's QuickAudio: https://github.com/BtheDestroyer/Godot_QuickAudio
# Distributed under MIT License
@icon("./icon.svg")
extends Node

@onready var tree := get_tree() # Gets the slightest of performance improvements by caching the SceneTree
func _ready() -> void: 
	process_mode = PROCESS_MODE_ALWAYS

func _play_sound(sound: AudioStream, player, autoplay := true, pitch_scale := 1.0, volume_db := 0.0, bus := "Master"):
	player.stream = sound
	player.autoplay = autoplay
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	player.bus = bus
	player.finished.connect(func(): player.queue_free())
	tree.current_scene.add_child(player)
	return player

# Use this for non-diagetic music or UI sounds which have no position
func play_sound(sound: AudioStream, autoplay := true, pitch_scale := 1.0, volume_db := 0.0, bus := "Master") -> AudioStreamPlayer:
	return _play_sound(sound, AudioStreamPlayer.new(), autoplay, pitch_scale, volume_db, bus)

# Use this for 2D gameplay sounds which should fade with distance
# Note: Remember to set the global_position or reparent(new_parent, false)!
func play_sound_2d(sound: AudioStream, autoplay := true, pitch_scale := 1.0, volume_db := 0.0, bus := "Master") -> AudioStreamPlayer2D:
	return _play_sound(sound, AudioStreamPlayer2D.new(), autoplay, pitch_scale, volume_db, bus)

# Use this for 3D gameplay sounds which should fade with distance
# Note: Remember to set the global_position or reparent(new_parent, false)!
func play_sound_3d(sound: AudioStream, autoplay := true, pitch_scale := 1.0, volume_db := 0.0, bus := "Master") -> AudioStreamPlayer3D:
	return _play_sound(sound, AudioStreamPlayer3D.new(), autoplay, pitch_scale, volume_db, bus)
	
	
#########################################
# Extra fun stuff for music transitions #
#########################################

func fade_in(audio_stream_player, seconds := 1.0, tween := create_tween()):
	if not (audio_stream_player is AudioStreamPlayer or audio_stream_player is AudioStreamPlayer2D or audio_stream_player is AudioStreamPlayer3D):
		push_error("Non-AudioStreamPlayer[XD] provided to Audio.fade_in(...)")
		return
	tween.tween_method(func(x): audio_stream_player.volume_db = linear_to_db(x), db_to_linear(audio_stream_player.volume_db), 1.0, seconds)
	
	
func fade_out(audio_stream_player, seconds := 1.0, tween := create_tween()):
	if not (audio_stream_player is AudioStreamPlayer or audio_stream_player is AudioStreamPlayer2D or audio_stream_player is AudioStreamPlayer3D):
		push_error("Non-AudioStreamPlayer[XD] provided to Audio.fade_out(...)")
		return
	tween.tween_method(func(x): audio_stream_player.volume_db = linear_to_db(x), db_to_linear(audio_stream_player.volume_db), 0.0, seconds)
	tween.tween_callback(func(): audio_stream_player.stop(); audio_stream_player.queue_free())
	
	
func cross_fade(audio_stream_player_out, audio_stream_player_in, seconds := 1.0, tween := create_tween()):
	if not (audio_stream_player_out is AudioStreamPlayer or audio_stream_player_out is AudioStreamPlayer2D or audio_stream_player_out is AudioStreamPlayer3D):
		push_error("Non-AudioStreamPlayer[XD] provided to Audio.cross_fade(...) as audio_stream_player_out")
		return
	if not (audio_stream_player_in is AudioStreamPlayer or audio_stream_player_in is AudioStreamPlayer2D or audio_stream_player_in is AudioStreamPlayer3D):
		push_error("Non-AudioStreamPlayer[XD] provided to Audio.cross_fade(...) as audio_stream_player_in")
		return
	fade_in(audio_stream_player_in, seconds, tween)
	fade_out(audio_stream_player_out, seconds, tween.parallel())

func sequential_fade(audio_stream_player_out, audio_stream_player_in, out_seconds := 1.0, in_seconds := out_seconds, tween := create_tween(), empty_seconds := 0.0):
	if not (audio_stream_player_out is AudioStreamPlayer or audio_stream_player_out is AudioStreamPlayer2D or audio_stream_player_out is AudioStreamPlayer3D):
		push_error("Non-AudioStreamPlayer[XD] provided to Audio.sequential_fade(...) as audio_stream_player_out")
		return
	if not (audio_stream_player_in is AudioStreamPlayer or audio_stream_player_in is AudioStreamPlayer2D or audio_stream_player_in is AudioStreamPlayer3D):
		push_error("Non-AudioStreamPlayer[XD] provided to Audio.sequential_fade(...) as audio_stream_player_in")
		return
	fade_out(audio_stream_player_out, out_seconds, tween)
	if empty_seconds > 0.0:
		tween.tween_interval(empty_seconds)
	fade_in(audio_stream_player_in, in_seconds, tween)

##########################
# Sound control utilities
##########################

# Gradually adjust pitch over time
func tween_pitch(audio_stream_player, target_pitch: float, seconds := 1.0, tween := create_tween()):
	if not (audio_stream_player is AudioStreamPlayer or audio_stream_player is AudioStreamPlayer2D or audio_stream_player is AudioStreamPlayer3D):
		push_error("Non-AudioStreamPlayer[XD] provided to Audio.tween_pitch(...)")
		return
	tween.tween_property(audio_stream_player, "pitch_scale", target_pitch, seconds)
	return tween

# Gradually adjust volume over time
func tween_volume(audio_stream_player, target_volume_db: float, seconds := 1.0, tween := create_tween()):
	if not (audio_stream_player is AudioStreamPlayer or audio_stream_player is AudioStreamPlayer2D or audio_stream_player is AudioStreamPlayer3D):
		push_error("Non-AudioStreamPlayer[XD] provided to Audio.tween_volume(...)")
		return
	tween.tween_property(audio_stream_player, "volume_db", target_volume_db, seconds)
	return tween

# Create a player with random pitch variation
func play_sound_with_random_pitch(sound: AudioStream, min_pitch := 0.9, max_pitch := 1.1, autoplay := true, volume_db := 0.0, bus := "Master") -> AudioStreamPlayer:
	var random_pitch = randf_range(min_pitch, max_pitch)
	return play_sound(sound, autoplay, random_pitch, volume_db, bus)

# Create a 2D player with random pitch variation
func play_sound_2d_with_random_pitch(sound: AudioStream, min_pitch := 0.9, max_pitch := 1.1, autoplay := true, volume_db := 0.0, bus := "Master") -> AudioStreamPlayer2D:
	var random_pitch = randf_range(min_pitch, max_pitch)
	return play_sound_2d(sound, autoplay, random_pitch, volume_db, bus)

# Create a 3D player with random pitch variation
func play_sound_3d_with_random_pitch(sound: AudioStream, min_pitch := 0.9, max_pitch := 1.1, autoplay := true, volume_db := 0.0, bus := "Master") -> AudioStreamPlayer3D:
	var random_pitch = randf_range(min_pitch, max_pitch)
	return play_sound_3d(sound, autoplay, random_pitch, volume_db, bus)

# Play a sound with volume in linear range (0.0 to 1.0) instead of decibels
func play_sound_linear(sound: AudioStream, volume_linear := 1.0, autoplay := true, pitch_scale := 1.0, bus := "Master") -> AudioStreamPlayer:
	var volume_db = linear_to_db(max(volume_linear, 0.0001)) # Avoid -INF by clamping minimum
	return play_sound(sound, autoplay, pitch_scale, volume_db, bus)

# Play a 2D sound with volume in linear range (0.0 to 1.0) instead of decibels
func play_sound_2d_linear(sound: AudioStream, volume_linear := 1.0, autoplay := true, pitch_scale := 1.0, bus := "Master") -> AudioStreamPlayer2D:
	var volume_db = linear_to_db(max(volume_linear, 0.0001)) # Avoid -INF by clamping minimum
	return play_sound_2d(sound, autoplay, pitch_scale, volume_db, bus)

# Play a 3D sound with volume in linear range (0.0 to 1.0) instead of decibels
func play_sound_3d_linear(sound: AudioStream, volume_linear := 1.0, autoplay := true, pitch_scale := 1.0, bus := "Master") -> AudioStreamPlayer3D:
	var volume_db = linear_to_db(max(volume_linear, 0.0001)) # Avoid -INF by clamping minimum
	return play_sound_3d(sound, autoplay, pitch_scale, volume_db, bus)
