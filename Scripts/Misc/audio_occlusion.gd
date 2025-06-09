extends AudioStreamPlayer3D
class_name SimpleAudioOcclusion

## How much to reduce volume per wall (0.0 to 1.0)
@export var occlusion_per_wall: float = 0.3

## How often to check for occlusion in seconds
@export var check_interval: float = 0.1

var base_volume_db: float
var timer: float = 0.0
var player: Node3D
var 	module_name: String = "SimpleAudioOcclusion"
func _ready():

	DebugLogger.register_module("SimpleAudioOcclusion")
	
	base_volume_db = volume_db
	player = get_tree().get_first_node_in_group("player")
	
	if not player:
		DebugLogger.debug(module_name,  "No player found!")

func _physics_process(delta):
	if not playing or not player:
		return
		
	timer += delta
	if timer < check_interval:
		return
		
	timer = 0.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, player.global_position)
	query.collide_with_areas = false
	
	var walls = 0
	var pos = global_position
	
	# Simple wall counting
	while walls < 5:
		var hit = space_state.intersect_ray(query)
		if hit.is_empty():
			break
		walls += 1
		pos = hit.position + (player.global_position - global_position).normalized() * 0.01
		query.from = pos
	
	var reduction = walls * occlusion_per_wall
	volume_db = base_volume_db + linear_to_db(max(0.1, 1.0 - reduction))
	DebugLogger.debug(module_name, "Walls: " + str(walls) + ", Volume: " + str(volume_db))
