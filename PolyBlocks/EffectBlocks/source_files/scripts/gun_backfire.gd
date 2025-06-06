extends MeshInstance3D

@export var auto_animate: bool = false
@export var distance = 0.02
@export var duration = 0.05
@export var cooldown = 0.1

var is_backfiring = false
var backfire_timer = 0.0
var cooldown_timer = 0.0
var is_on_cooldown = false
var original_position = Vector3.ZERO
var backfire_position = Vector3.ZERO

func _ready():
	original_position = position

func _process(delta):
	if is_on_cooldown:
		cooldown_timer += delta
		if cooldown_timer >= cooldown:
			is_on_cooldown = false
			cooldown_timer = 0.0
	
	if Input.is_action_just_pressed("ui_select") and not is_backfiring and not is_on_cooldown:
		start_backfire()
	
	if is_backfiring:
		backfire_timer += delta
		
		if backfire_timer <= duration / 2:
			var t = backfire_timer / (duration / 2)
			position = original_position.lerp(backfire_position, t)
		elif backfire_timer <= duration:
			var t = (backfire_timer - duration / 2) / (duration / 2)
			position = backfire_position.lerp(original_position, t)
		else:
			position = original_position
			is_backfiring = false
			backfire_timer = 0.0
			
			start_cooldown()

func start_backfire():
	is_backfiring = true
	backfire_timer = 0.0
	
	backfire_position = original_position + global_transform.basis.z * distance

func start_cooldown():
	is_on_cooldown = true
	cooldown_timer = 0.0
