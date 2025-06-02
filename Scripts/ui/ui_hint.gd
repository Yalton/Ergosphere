# HintUI.gd
extends Control
class_name HintUI

@export var hint_label: Label
@export var hint_duration: float = 4.0

var removal_timer: Timer

func _ready() -> void:
	# Create removal timer
	removal_timer = Timer.new()
	removal_timer.one_shot = true
	removal_timer.timeout.connect(_remove_hint)
	add_child(removal_timer)
	
	# Start timer immediately
	removal_timer.start(hint_duration)

func set_hint_text(text: String) -> void:
	if hint_label:
		hint_label.text = text

func _remove_hint() -> void:
	queue_free()
