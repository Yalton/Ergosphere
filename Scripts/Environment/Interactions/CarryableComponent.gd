extends InteractionComponent
class_name CarryableComponent

@export_group("Carriable Settings")
@export var pick_up_sound : AudioStream
@export var drop_sound : AudioStream
##Sets whether the object can be carried while wielding a weapon
@export var is_carryable_while_wielding : bool = true  # Changed default to true since we're simplifying
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
var is_being_carried : bool = false
var player_interaction_component : PlayerInteractionComponent
var carry_position : Vector3 #Position the carriable "floats towards".
var desired_rotation: Vector3 = Vector3.ZERO

func _ready() -> void:
	parent_object = get_parent()
	
	# Set initial interaction text
	interaction_text = "Pick up " + parent_object.name
	
	# Connect to body entered signal if available (for collision detection)
	if parent_object.has_signal("body_entered"):
		parent_object.body_entered.connect(_on_body_entered)
	
	# Warn if not attached to a proper physics object
	if not (parent_object is RigidBody3D):
		push_warning(parent_object.name + ": CarriableComponent works best when attached to a RigidBody3D.")
	
	# Ensure we have the audio player component
	if not has_node("AudioStreamPlayer3D"):
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "AudioStreamPlayer3D"
		audio_player.max_distance = 10.0
		audio_player.unit_size = 1.0
		add_child(audio_player)
		audio_stream_player_3d = audio_player

func interact(_player_interaction_component:PlayerInteractionComponent) -> void:
	if !is_disabled:
		carry(_player_interaction_component)

func carry(_player_interaction_component:PlayerInteractionComponent) -> void:
	player_interaction_component = _player_interaction_component
	
	# Simplified check for wielding
	if player_interaction_component.is_wielding and not is_carryable_while_wielding:
		player_interaction_component.send_hint(null, "Can't carry an object while wielding.")
		return

	if is_being_carried:
		leave()
	else:
		hold()

func _on_rotate_carried_object(supplied_rotation: Vector3) -> void:
	if is_being_carried:
		desired_rotation += supplied_rotation
		
func _physics_process(delta : float) -> void:
	if is_being_carried:
		# Get the target position from the carryable_position node
		carry_position = player_interaction_component.get_interaction_raycast_tip(carry_distance_offset)
		
		# Calculate vector to desired position
		var direction_vector = carry_position - parent_object.global_position
		var distance = direction_vector.length()
		
		# If we're too far from carry position, drop the object
		#if distance >= drop_distance:
			#leave()
			#return
		
		# Use velocity-based approach for smoother physics
		var target_velocity = direction_vector * carrying_velocity_multiplier 
		
		# Apply the velocity to move the object
		parent_object.set_linear_velocity(target_velocity)
		
		# Handle rotation
		parent_object.set_rotation(desired_rotation)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and is_being_carried:
		leave()

func _exit_tree() -> void:
	if is_being_carried:
		leave()

func hold() -> void:
	# Lock rotation if applicable
	if lock_rotation_when_carried:
		# For RigidBody3D
		if parent_object is RigidBody3D:
			parent_object.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			# Ensure object doesn't have gravity while carrying
			parent_object.gravity_scale = 0
		# For older versions or different objects
		if parent_object.has_method("set_lock_rotation_enabled"):
			parent_object.set_lock_rotation_enabled(true)
	
	# Tell the player component we're being carried
	player_interaction_component.start_carrying(self)
	
	# Make sure the raycast doesn't collide with this object
	player_interaction_component.interaction_raycast.add_exception(parent_object)
	
	# Store current rotation as the desired rotation
	desired_rotation = parent_object.rotation
	
	# Connect to rotation signal
	if !player_interaction_component.is_connected("rotate_carried_object", _on_rotate_carried_object):
		player_interaction_component.rotate_carried_object.connect(_on_rotate_carried_object)

	# Play pick up sound
	if pick_up_sound != null and audio_stream_player_3d:
		audio_stream_player_3d.stream = pick_up_sound
		audio_stream_player_3d.play()
	
	# Update state
	is_being_carried = true
	interaction_text = "Drop " + parent_object.name

func leave() -> void:
	# Restore physics properties
	if lock_rotation_when_carried:
		# For RigidBody3D
		if parent_object is RigidBody3D:
			parent_object.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			parent_object.gravity_scale = 1.0  # Restore normal gravity
		
		# For older versions or different objects
		if parent_object.has_method("set_lock_rotation_enabled"):
			parent_object.set_lock_rotation_enabled(false)
	
	# Handle player interaction component cleanup
	if player_interaction_component and is_instance_valid(player_interaction_component):
		# Tell player we're no longer carried
		player_interaction_component.stop_carrying()
		
		# Remove raycast exception
		player_interaction_component.interaction_raycast.remove_exception(parent_object)
		
		# Disconnect rotation signal if connected
		if player_interaction_component.is_connected("rotate_carried_object", _on_rotate_carried_object):
			player_interaction_component.rotate_carried_object.disconnect(_on_rotate_carried_object)
	
	# Update state
	is_being_carried = false
	interaction_text = "Pick up " + parent_object.name

func throw(power : float) -> void:
	leave()
	if drop_sound and audio_stream_player_3d:
		audio_stream_player_3d.stream = drop_sound
		audio_stream_player_3d.play()
		
	print(name, ": Throwing with impulse force ", player_interaction_component.Get_Look_Direction() * power)
	parent_object.apply_central_impulse(player_interaction_component.Get_Look_Direction() * power)

func get_mass() -> float:
	return parent_object.mass if parent_object.has_method("get_mass") else 1.0
