class_name HermesVoiceClip
extends Resource

## Voice clip resource that contains subtitle timing without audio streams
## Now focused purely on subtitle timing and text content

## Unique identifier for this voice clip
@export var id: String
## Optional description or transcript of the voice clip
@export_multiline var description: String = ""
## Array of subtitle lines for this voice clip - these drive the phoneme timing
@export var subtitle_lines: Array[HermesSubtitleLine] = []
## Can this voice line be said more than once?
@export var is_repeatable: bool = true

func _init(p_id: String = "", p_description: String = "") -> void:
	id = p_id
	description = p_description

## Get total duration of this voice clip based on subtitle lines
func get_total_duration() -> float:
	if subtitle_lines.is_empty():
		return 0.0
	
	var max_end_time = 0.0
	for line in subtitle_lines:
		if line.end_time > max_end_time:
			max_end_time = line.end_time
	
	return max_end_time

## Get the number of words across all subtitle lines (for phoneme calculation)
func get_total_word_count() -> int:
	var total_words = 0
	for line in subtitle_lines:
		total_words += line.text.split(" ").size()
	return total_words
