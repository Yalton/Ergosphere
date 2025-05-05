extends InteractionComponent
class_name CarryableComponent

@export_group("Carriable Settings")
@export var pick_up_sound : AudioStream
@export var drop_sound : AudioStream
##Sets whether the object can be carried while wielding a weapon
@export var is_carryable_while_wielding : bool = false
## Use this to adjust the carry position distance from the player. Per default it's the interaction raycast length. Negative values are closer, positive values are further away.
@export var carry_distance_offset : float = 0
## Set if the object should not rotate when being carried. Usually true is preferred.
@export var lock_rotation_when_carried : bool = true
## Sets how fast the carriable is being pulled towards the carrying position. The lower, the "floatier" it will feel.
@export var carrying_velocity_multiplier : float = 10
## Sets how far away the carried object needs to be from the carry_position before it gets dropped.
@export var drop_distance : float = 1.5

@onready var audio_stream_player_3d : AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var camera : Camera3D = get_viewport().get_camera_3d()


var parent_object : CollisionObject3D
var is_being_carried : bool
var player_interaction_component : PlayerInteractionComponent
var carry_position : Vector3 #Position the carriable "floats towards".
var desired_rotation: Vector3 = Vector3.ZERO

func _ready() -> void:
	parent_object = get_parent()
	if parent_object.has_signal("body_entered"):
		parent_object.body_entered.connect(_on_body_entered) #Connecting to body entered signal
	else:
		print(parent_object.name, ": CarriableComponent needs to be child to a RigidBody3D to work.")


func interact(_player_interaction_component:PlayerInteractionComponent) -> void:
	if !is_disabled:
		carry(_player_interaction_component)




func carry(_player_interaction_component:PlayerInteractionComponent) -> void:
	player_interaction_component = _player_interaction_component
	if player_interaction_component.is_wielding and not is_carryable_while_wielding:
		player_interaction_component.send_hint(null,"Can't carry an object while wielding.")
		return

	if is_being_carried:
		leave()
	else:
		hold()

func _on_rotate_carried_object(supplied_rotation: Vector3) -> void:
	if is_being_carried:
		desired_rotation += supplied_rotation
		DebugLogging.log_message(["Desired rotation: ", desired_rotation])
		
func _physics_process(_delta : float) -> void:
	if is_being_carried:
		carry_position = player_interaction_component.get_interaction_raycast_tip(carry_distance_offset)
		parent_object.set_linear_velocity((carry_position - parent_object.global_position) * carrying_velocity_multiplier)
		
		parent_object.set_rotation(desired_rotation)
		
		if(carry_position-parent_object.global_position).length() >= drop_distance:
			leave()
		#DebugLogging.log_message(["Carried object rotation in _physics_process: ", parent_object.rotation])

#func get_carrier():
	#if is_being_carried:
		#return player_interaction_component.get_parent()
	#else: 
		#return null 
		
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and is_being_carried:
		leave()


func _exit_tree() -> void:
	if is_being_carried:
		leave()


func hold() -> void:
	if lock_rotation_when_carried:
		parent_object.set_lock_rotation_enabled(true)
	player_interaction_component.start_carrying(self)
	player_interaction_component.interaction_raycast.add_exception(parent_object)
	
	#parent_object.set_rotation(Vector3(1.570796, 0.000003, 0))
	desired_rotation = parent_object.rotation
	player_interaction_component.rotate_carried_object.connect(_on_rotate_carried_object)

	# print("Carried object rotation in hold(): ", parent_object.rotation)

	# Play Pick up sound.
	if pick_up_sound != null:
		audio_stream_player_3d.stream = pick_up_sound
		audio_stream_player_3d.play()
	
	is_being_carried = true


func leave() -> void:
	if lock_rotation_when_carried:
		parent_object.set_lock_rotation_enabled(false)
	if player_interaction_component and is_instance_valid(player_interaction_component):
		player_interaction_component.stop_carrying()
		player_interaction_component.interaction_raycast.remove_exception(parent_object)
	player_interaction_component.rotate_carried_object.disconnect(_on_rotate_carried_object)

	#print("Carried object rotation in leave(): ", parent_object.rotation)
	
	is_being_carried = false


func throw(power : float) -> void:
	leave()
	if drop_sound:
		audio_stream_player_3d.stream = drop_sound
		audio_stream_player_3d.play()
	print(name, ": Throwing with impulse force ", player_interaction_component.Get_Look_Direction() * power)
	parent_object.apply_central_impulse(player_interaction_component.Get_Look_Direction() * power)

func get_mass() -> float:
	return parent_object.mass
