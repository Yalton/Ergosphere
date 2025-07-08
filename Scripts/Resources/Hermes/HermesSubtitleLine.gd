class_name HermesSubtitleLine
extends Resource

## Start time of this subtitle line in seconds
@export var start_time: float = 0.0
## End time of this subtitle line in seconds
@export var end_time: float = 0.0
## The subtitle text to display
@export_multiline var text: String = ""

func _init(p_start_time: float = 0.0, p_end_time: float = 0.0, p_text: String = "") -> void:
	start_time = p_start_time
	end_time = p_end_time
	text = p_text

func is_active_at_time(current_time: float) -> bool:
	return current_time >= start_time and current_time <= end_time
