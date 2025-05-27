extends Node3D
class_name StaticInteractable


## Name that will displayed when interacting. Leave blank to hide
@export var display_name : String

var interaction_nodes : Array[Node]
var properties : int

func _ready():
	self.add_to_group("interactable")
	find_interaction_nodes()

func find_interaction_nodes():
	interaction_nodes = find_children("","InteractionComponent",true) #Grabs all attached interaction components
