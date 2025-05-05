class_name DiegeticUIBase
extends StaticBody3D

signal object_state_updated(interaction_text: String)
signal interaction_started
signal interaction_ended

@export_group("Interaction Settings")
@export var interact_sound: AudioStream
@export var usable_interaction_text: String = "Use UI"
@export var allows_repeated_interaction: bool = true
@export var interaction_cooldown_time: float
@export var has_been_used_hint: String
@export var unusable_interaction_text: String = "UI Locked"

@export_group("UI Control")
@export var sub_viewport: SubViewport
@export var display_sprite: Sprite3D

@onready var area_3d: Area3D = $Area3D

var last_interaction_point: Vector2 = Vector2.ZERO
var has_been_used: bool = false
var interaction_text: String
var player_interaction_component: PlayerInteractionComponent
var interaction_nodes: Array[Node]
var cooldown: float
var is_player_interacting: bool = false

func _ready() -> void:
	self.add_to_group("interactable")
	add_to_group("save_object_state")
	interaction_nodes = find_children("", "InteractionComponent", true)
	cooldown = 0
	interaction_text = usable_interaction_text
	object_state_updated.emit(interaction_text)
	sub_viewport.set_process_input(true)
	print("Diegetic UI initialized")

func _physics_process(delta: float) -> void:
	if cooldown > 0:
		cooldown -= delta

func interact(_player_interaction_component: PlayerInteractionComponent) -> void:
	if is_player_interacting:
		end_interaction()
		return
	
	if cooldown > 0:
		return
	
	player_interaction_component = _player_interaction_component
	if !allows_repeated_interaction and has_been_used:
		player_interaction_component.send_hint(null, has_been_used_hint)
		return
	
	start_interaction()

func start_interaction() -> void:
	if interact_sound:
		Audio.play_sound_3d(interact_sound).global_position = global_position
	
	player_interaction_component.ray_cast.add_exception(self)
		
	if !allows_repeated_interaction:
		has_been_used = true
		interaction_text = unusable_interaction_text
		object_state_updated.emit(interaction_text)
	else:
		cooldown = interaction_cooldown_time
	
	is_player_interacting = true
	player_interaction_component.diegetic_ui_interaction_started(self)
	interaction_started.emit()
	set_process_input(true)
	print("UI interaction started")

func _input(event: InputEvent) -> void:
	if !is_player_interacting:
		return

	if event.is_action_pressed("menu") or event.is_action_pressed("interact"):
		print("Menu key pressed, ending interaction")
		end_interaction()
		return

	# Pass all events to the viewport, including mouse clicks
	if event is InputEventMouseButton:
		var viewport_event = event.duplicate()
		viewport_event.position = last_interaction_point
		viewport_event.global_position = last_interaction_point
		#print("Pushing Event ", viewport_event, " at position ", viewport_event.position)
		sub_viewport.push_input(viewport_event)
	else:
		sub_viewport.push_input(event)

func handle_interaction(local_point: Vector3) -> void:
	var sprite_size: Vector2 = display_sprite.texture.get_size() * display_sprite.pixel_size if display_sprite.texture else Vector2.ONE

	# Normalize the point
	var point_2d = Vector2(local_point.x, -local_point.y)
	point_2d = (point_2d / sprite_size) + Vector2(0.5, 0.5)

	# Scale to viewport size
	point_2d *= Vector2(sub_viewport.size)

	var event = InputEventMouseMotion.new()
	event.position = point_2d
	event.global_position = point_2d

	if last_interaction_point != Vector2.ZERO:
		event.relative = point_2d - last_interaction_point
	else:
		event.relative = Vector2.ZERO

	last_interaction_point = point_2d

	# Send the event to the viewport
	sub_viewport.push_input(event)

func end_interaction() -> void:
	set_process_input(false)
	is_player_interacting = false
	last_interaction_point = Vector2.ZERO
	player_interaction_component.interaction_raycast.remove_exception(self)
	if player_interaction_component:
		player_interaction_component.diegetic_ui_interaction_ended()
	interaction_ended.emit()
	print("UI interaction ended")

func on_damage_received() -> void:
	if is_player_interacting:
		end_interaction()
	print("Damage received, ending interaction")

func force_end_interaction() -> void:
	if is_player_interacting:
		end_interaction()
	print("Forced end of interaction")

func set_state() -> void:
	if has_been_used:
		interaction_text = unusable_interaction_text
	else:
		interaction_text = usable_interaction_text
	object_state_updated.emit(interaction_text)
