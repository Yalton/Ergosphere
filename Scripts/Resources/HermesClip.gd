class_name HermesVoiceClip
extends Resource

## Unique identifier for this voice clip
@export var id: String
## The audio stream for this voice clip
@export var audio_stream: AudioStream
## Optional description or transcript of the voice clip
@export_multiline var description: String = ""
## Array of subtitle lines for this voice clip
@export var subtitle_lines: Array[HermesSubtitleLine] = []

func _init(p_id: String = "", p_audio_stream: AudioStream = null, p_description: String = "") -> void:
	id = p_id
	audio_stream = p_audio_stream
	description = p_description

## Find subtitle lines that should be active at the given playback time
func get_active_subtitle(current_time: float) -> String:
	for line in subtitle_lines:
		if line.is_active_at_time(current_time):
			return line.text
	return ""
