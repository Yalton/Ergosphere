# AreaInteractionForwarder.gd
extends Area3D
class_name AreaInteractionForwarder

signal object_state_updated(interaction_text: String)

## Debug settings
@export var enable_debug: bool = true
var module_name: String = "AreaInteractionForwarder"

var interaction_nodes: Array[Node]
var target_node: Node3D

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Add to interactable group
	add_to_group("interactable")
	
	# Get parent as target
	target_node = get_parent()
	
	if not target_node:
		DebugLogger.error(module_name, "No parent node found!")
		return
	
	# Find interaction components (same as GameObject)
	find_interaction_nodes()
	
	DebugLogger.debug(module_name, "Area interaction forwarder ready, targeting: " + target_node.name + " with " + str(interaction_nodes.size()) + " interaction components")

func find_interaction_nodes():
	interaction_nodes = find_children("", "InteractionComponent", true)

# This gets called by the player interaction system
func interact(player_interaction: PlayerInteractionComponent) -> void:
	target_node.interact(player_interaction)

## Forward interaction text requests
#func get_interaction_text() -> String:
	## Try interaction components first
	#if interaction_nodes.size() > 0:
		#var interaction_component = interaction_nodes[0]
		#if interaction_component.has_method("get_interaction_text"):
			#return interaction_component.get_interaction_text()
		#elif interaction_component.has_property("interaction_text"):
			#return interaction_component.interaction_text
	#
	## Fallback to target
	#if target_node and target_node.has_method("get_interaction_text"):
		#return target_node.get_interaction_text()
	#elif target_node and target_node.has_property("display_name") and target_node.display_name != "":
		#return "Interact with " + target_node.display_name
	#
	#return "Interact"
