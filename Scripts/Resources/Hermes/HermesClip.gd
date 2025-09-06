class_name HermesVoiceClip
extends Resource

## Voice clip resource that contains audio and subtitle timing information
## Used by HermesAudio to play voice lines with synchronized subtitles

## Unique identifier for this voice clip
@export var id: String

## The actual audio file to play
@export var audio_stream: AudioStream


## Array of subtitle lines with timing information
@export var subtitle_lines: Array[HermesSubtitleLine] = []

## Can this voice line be said more than once?
@export var is_repeatable: bool = true

func _init(p_id: String = "", p_description: String = "") -> void:
	id = p_id

## Get total duration of this voice clip based on the audio stream
func get_total_duration() -> float:
	if audio_stream:
		return audio_stream.get_length()
	
	# Fallback to subtitle timing if no audio stream
	if subtitle_lines.is_empty():
		return 0.0
	
	var max_end_time = 0.0
	for line in subtitle_lines:
		if line.end_time > max_end_time:
			max_end_time = line.end_time
	
	return max_end_time
