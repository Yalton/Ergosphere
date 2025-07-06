extends Node3D
class_name Station

@export var ending_choice_container: Node3D
@export var alt_a_marker: Node3D
@export var alt_b_marker: Node3D

func _ready() -> void:
	SettingsManager.apply_hermes_mute_setting()
