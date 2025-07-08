class_name Door
extends Node3D

signal door_state_changed(is_open)
signal lock_state_changed(is_locked)

enum DoorType {
	SWING,
	SLIDE
}

# Common door properties
@export var open_sound: AudioStream
@export var close_sound: AudioStream
@export var rattle_sound: AudioStream
@export var is_open: bool = false
@export var is_locked: bool = false
@export var door_speed: float = 0.1
@export var door_type: DoorType = DoorType.SWING
@export var audio_player : AudioStreamPlayer3D
# Swing door properties
@export_group("Swing Door Properties")
@export var open_rotation_deg: float = 90.0
@export var closed_rotation_deg: float = 0.0

# Slide door properties
@export_group("Slide Door Properties")
@export var slide_direction: Vector3 = Vector3(1, 0, 0)  # Direction to slide
@export var slide_distance: float = 2.0  # How far to slide

## If true, door will reset to closed state when day resets
@export var reset_on_new_day: bool = true

# Tracking variables
var is_moving: bool = false
var target_rotation_rad: float
var initial_position: Vector3
var target_position: Vector3
var debug_module_name: String = "Door"

func _ready() -> void:
	DebugLogger.register_module(debug_module_name, true)
	add_to_group("interactable")
	
	# Store initial position for sliding doors
	initial_position = position
	
	# Initialize based on door type
	if door_type == DoorType.SWING:
		target_rotation_rad = rotation.y
		
		if is_open:
			rotation.y = deg_to_rad(open_rotation_deg)
		else:
			rotation.y = deg_to_rad(closed_rotation_deg)
	else:  # SLIDE
		if is_open:
			position = initial_position + slide_direction.normalized() * slide_distance
		target_position = position
	
	# Connect to GameManager's day_reset signal
	if reset_on_new_day and GameManager:
		GameManager.day_ended.connect(_on_day_ended)
		DebugLogger.debug(debug_module_name, "Connected to day_reset signal")
	
	DebugLogger.debug(debug_module_name, "Door initialized: Type=" + 
		("Swing" if door_type == DoorType.SWING else "Slide") + 
		", IsOpen=" + str(is_open))

func _physics_process(_delta: float) -> void:
	if is_moving:
		if door_type == DoorType.SWING:
			rotation.y = lerp_angle(rotation.y, target_rotation_rad, door_speed)
			if abs(rotation.y - target_rotation_rad) <= 0.01:
				is_moving = false
				rotation.y = target_rotation_rad
				DebugLogger.debug(debug_module_name, "Swing door finished moving")
		else:  # SLIDE
			position = position.lerp(target_position, door_speed)
			if position.distance_to(target_position) <= 0.01:
				is_moving = false
				position = target_position
				DebugLogger.debug(debug_module_name, "Slide door finished moving")

func interact(_interactor: PlayerInteractionComponent) -> void:
	DebugLogger.debug(debug_module_name, "Door interaction: IsLocked=" + str(is_locked) + 
		", IsOpen=" + str(is_open))

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
	DebugLogger.debug(debug_module_name, "Opening door")
	
	if audio_player and open_sound:
		audio_player.stream = open_sound
		audio_player.play()
	
	if door_type == DoorType.SWING:
		target_rotation_rad = deg_to_rad(open_rotation_deg)
	else:  # SLIDE
		target_position = initial_position + slide_direction.normalized() * slide_distance
	
	is_moving = true
	is_open = true
	door_state_changed.emit(true)

func close_door() -> void:
	DebugLogger.debug(debug_module_name, "Closing door")
	
	if audio_player and close_sound:
		audio_player.stream = close_sound
		audio_player.play()
	
	if door_type == DoorType.SWING:
		target_rotation_rad = deg_to_rad(closed_rotation_deg)
	else:  # SLIDE
		target_position = initial_position
	
	is_moving = true
	is_open = false
	door_state_changed.emit(false)

func unlock() -> void:
	is_locked = false
	lock_state_changed.emit(false)
	DebugLogger.debug(debug_module_name, "Door unlocked")

func lock() -> void:
	is_locked = true
	lock_state_changed.emit(true)
	DebugLogger.debug(debug_module_name, "Door locked")

func _on_day_ended(day_number: int) -> void:
	if not reset_on_new_day:
		return
		
	DebugLogger.debug(debug_module_name, "Day reset signal received - closing door")
	
	# Force close the door without sound
	if door_type == DoorType.SWING:
		rotation.y = deg_to_rad(closed_rotation_deg)
		target_rotation_rad = rotation.y
	else:  # SLIDE
		position = initial_position
		target_position = position
	
	is_moving = false
	is_open = false
	door_state_changed.emit(false)
