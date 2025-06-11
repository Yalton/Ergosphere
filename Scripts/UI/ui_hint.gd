# HintUI.gd
extends Control
class_name HintUI

@export var hint_label: Label
@export var hint_duration: float = 4.0

var removal_timer: Timer

func _ready() -> void:
	removal_timer = CommonUtils.create_one_shot_timer(self, hint_duration, _remove_hint)

func set_hint_text(text: String) -> void:
	if hint_label:
		hint_label.text = text

func _remove_hint() -> void:
	queue_free()
