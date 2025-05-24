class_name SignalDoorInteraction
extends Node3D

@export var interaction_text: String = "Use Door"

func _ready() -> void:
	# Pass through the parent's interaction text if available
	var parent = get_parent()
	if parent and parent.has_method("get_interaction_text"):
		interaction_text = parent.get_interaction_text()

func get_interaction_text() -> String:
	return interaction_text

func interact(player_interaction) -> void:
	var parent = get_parent()
	if parent and parent.has_method("interact"):
		parent.interact(player_interaction)
