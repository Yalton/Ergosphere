extends Node3D
class_name GameObject

signal object_exits_tree()

## Name that will displayed when interacting. Leave blank to hide
@export var display_name : String
@export var enable_debug: bool = true

var interaction_nodes : Array[Node]
var properties : int


func _ready():
	self.add_to_group("interactable")
	self.add_to_group("Persist") #Adding object to group for persistence
	find_interaction_nodes()
	


func find_interaction_nodes():
	interaction_nodes = find_children("","InteractionComponent",true) #Grabs all attached interaction components

#func find_rigid_body() -> RigidBody3D:
	#var current = self
	#while current:
		#if current is RigidBody3D:
			#return current as RigidBody3D
		#current = current.get_parent()
	#return null

func _exit_tree() -> void:
	object_exits_tree.emit()
