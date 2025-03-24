class_name Door
extends Node3D

signal door_state_changed(is_open)
signal lock_state_changed(is_locked)

@export var open_sound: AudioStream
@export var close_sound: AudioStream
@export var rattle_sound: AudioStream
@export var is_open: bool = false
@export var is_locked: bool = false
@export var open_rotation_deg: float = 90.0
@export var closed_rotation_deg: float = 0.0
@export var door_speed: float = 0.1

@onready var audio_player = $AudioStreamPlayer3D

var is_moving: bool = false
var target_rotation_rad: float

func _ready() -> void:
	add_to_group("interactable")
	target_rotation_rad = rotation.y
	
	if is_open:
		rotation.y = deg_to_rad(open_rotation_deg)
	else:
		rotation.y = deg_to_rad(closed_rotation_deg)

func _physics_process(delta: float) -> void:
	if is_moving:
		rotation.y = lerp_angle(rotation.y, target_rotation_rad, door_speed)
		if abs(rotation.y - target_rotation_rad) <= 0.01:
			is_moving = false
			rotation.y = target_rotation_rad

func interact(interactor) -> void:
	if is_locked:
		if audio_player and rattle_sound:
			audio_player.stream = rattle_sound
			audio_player.play()
		return
		
	if is_open:
		close_door()
	else:
		open_door()

func open_door() -> void:
	if audio_player and open_sound:
		audio_player.stream = open_sound
		audio_player.play()
	
	target_rotation_rad = deg_to_rad(open_rotation_deg)
	is_moving = true
	is_open = true
	door_state_changed.emit(true)

func close_door() -> void:
	if audio_player and close_sound:
		audio_player.stream = close_sound
		audio_player.play()
	
	target_rotation_rad = deg_to_rad(closed_rotation_deg)
	is_moving = true
	is_open = false
	door_state_changed.emit(false)

func unlock() -> void:
	is_locked = false
	lock_state_changed.emit(false)

func lock() -> void:
	is_locked = true
	lock_state_changed.emit(true)
