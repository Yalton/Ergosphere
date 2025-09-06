class_name HermesSubtitleLine
extends Resource

## Subtitle line with timing information for synchronized display with audio
## Used by HermesVoiceClip to define when subtitles appear and disappear

## The subtitle text to display
@export_multiline var text: String = ""

## Start time in seconds when this subtitle should appear
@export var start_time: float = 0.0

## End time in seconds when this subtitle should disappear
@export var end_time: float = 1.0

func _init(p_text: String = "", p_start: float = 0.0, p_end: float = 1.0) -> void:
	text = p_text
	start_time = p_start
	end_time = p_end

## Get the duration of this subtitle line
func get_duration() -> float:
	return end_time - start_time
