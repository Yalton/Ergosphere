extends Camera3D

@export var move_speed: float = 5.0
@export var speed_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.005
@export var max_pitch: float = 1.5
@export var min_pitch: float = -1.5

var rotation_h: float = 0.0
var rotation_v: float = 0.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		rotation_h -= event.relative.x * mouse_sensitivity
		rotation_v -= event.relative.y * mouse_sensitivity
		rotation_v = clamp(rotation_v, min_pitch, max_pitch)
		transform.basis = Basis()
		rotate_object_local(Vector3.UP, rotation_h)
		rotate_object_local(Vector3.RIGHT, rotation_v)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	var input_dir = Vector3.ZERO
	var current_speed = move_speed
	
	if Input.is_action_pressed("shift"):
		current_speed *= speed_multiplier
	if Input.is_action_pressed("ui_up") or Input.is_action_pressed("w"):
		input_dir.z -= 1
	if Input.is_action_pressed("ui_down") or Input.is_action_pressed("s"):
		input_dir.z += 1
	if Input.is_action_pressed("ui_left") or Input.is_action_pressed("a"):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_action_pressed("d"):
		input_dir.x += 1
	if Input.is_action_pressed("q"):
		input_dir.y += 1
	if Input.is_action_pressed("e"):
		input_dir.y -= 1

	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
	
	var movement = transform.basis * input_dir * current_speed * delta
	var new_position = transform.origin + movement

	new_position.x = clamp(new_position.x, -10.0, 50.0)
	new_position.y = clamp(new_position.y, 1.0, 15.0)
	new_position.z = clamp(new_position.z, -10.0, 10.0)

	transform.origin = new_position
