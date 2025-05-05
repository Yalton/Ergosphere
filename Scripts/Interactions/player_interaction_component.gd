class_name PlayerInteractionComponent
extends Node3D

@export var ui_controller: FPCUIController
@export var interaction_action: String = "interact"  # Input action name

@onready var ray_cast = $"../Head/Camera3D/RayCast3D"  # Path to your raycast
var current_interactable = null

func _ready() -> void:
	if not ui_controller:
		push_error("PlayerInteraction requires a UI Controller reference")

func _process(_delta: float) -> void:
	update_interaction()
	
	if Input.is_action_just_pressed(interaction_action) and current_interactable:
		interact_with_current()

func update_interaction() -> void:
	if ray_cast.is_colliding():
		var collider = ray_cast.get_collider()
		if collider.is_in_group("interactable"):
			# Try to get interaction component
			var interaction = find_interaction_component(collider)
			
			# If we found a valid interaction and it's different from our current one
			if interaction and current_interactable != interaction:
				current_interactable = interaction
				ui_controller.show_interaction(interaction.interaction_text)
			return
	
	# Nothing found, clear interaction
	if current_interactable:
		ui_controller.hide_interaction()
		current_interactable = null

func interact_with_current() -> void:
	if current_interactable:
		# Get the parent interactable object (usually Door or similar)
		var parent_interactable = current_interactable.get_parent()
		if parent_interactable and parent_interactable.has_method("interact"):
			parent_interactable.interact(self)
		elif current_interactable.has_method("interact"):
			current_interactable.interact(self)

func find_interaction_component(node) -> Node:
	# First check if the node itself has interaction text
	if node.has_method("get_interaction_text") or node.get("interaction_text") != null:
		return node
	
	# Check for a dedicated interaction component
	for child in node.get_children():
		if child.has_method("get_interaction_text") or child.get("interaction_text") != null:
			return child
	
	return null

# Helper method to send messages from gameplay
func send_message(text: String) -> void:
	if ui_controller:
		ui_controller.show_message(text)
