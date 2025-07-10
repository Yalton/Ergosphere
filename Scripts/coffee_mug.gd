# CoffeeMug.gd
extends GameObject
class_name CoffeeMug

## Minimum impact velocity to break the mug
@export var break_velocity_threshold: float = 5.0

## Shattered mug scene (using modified ShatteredScanner)
@export var shattered_mug_scene: PackedScene

## Sound played on impact (not breaking)
@export var impact_sound: AudioStream

## Break sound (played when mug shatters)
@export var break_sound: AudioStream

## Path to the RigidBody3D child node
@export var rigid_body_path: NodePath = "RigidBody3D"

# Signals
signal mug_broken

# Internal
var module_name: String = "CoffeeMug"
var has_broken: bool = false
var rigid_body: RigidBody3D

func _ready() -> void:
	super._ready()
	DebugLogger.register_module(module_name, enable_debug)
	
	# Find the RigidBody3D child
	rigid_body = get_node(rigid_body_path)
	if not rigid_body:
		DebugLogger.error(module_name, "RigidBody3D not found at path: " + str(rigid_body_path))
		return
	
	# Setup collision detection
	rigid_body.body_entered.connect(_on_body_entered)
	
	# Ensure physics properties
	rigid_body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	rigid_body.freeze = false
	rigid_body.gravity_scale = 1.0
	rigid_body.continuous_cd = true
	
	DebugLogger.debug(module_name, "Coffee mug spawned")

func _on_body_entered(body: Node) -> void:
	if has_broken:
		return
	
	# Get impact velocity
	var impact_velocity = rigid_body.linear_velocity.length()
	
	DebugLogger.debug(module_name, "Impact detected. Velocity: " + str(impact_velocity))
	
	if impact_velocity >= break_velocity_threshold:
		_break_mug()
	else:
		_play_impact_sound()

func _play_impact_sound() -> void:
	if not impact_sound:
		return
		
	var audio_player = AudioStreamPlayer3D.new()
	audio_player.stream = impact_sound
	audio_player.max_distance = 15.0
	audio_player.unit_size = 1.0
	audio_player.autoplay = true
	add_child(audio_player)
	audio_player.finished.connect(func(): audio_player.queue_free())

func _break_mug() -> void:
	if has_broken:
		return
		
	has_broken = true
	
	DebugLogger.info(module_name, "Mug breaking!")
	
	# Spawn shattered version
	if shattered_mug_scene:
		var shattered = shattered_mug_scene.instantiate()
		get_tree().current_scene.add_child(shattered)
		shattered.initialize(global_position, global_rotation)
		
		# Pass break sound to shattered scanner if it doesn't have one
		if break_sound and not shattered.explosion_sound:
			shattered.explosion_sound = break_sound
	
	# Emit signal
	mug_broken.emit()
	
	# Remove self
	queue_free()
