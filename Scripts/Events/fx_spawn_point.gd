# VFXSpawnPoint.gd
extends VisibleOnScreenNotifier3D
class_name VFXSpawnPoint

## Simple VFX spawn point that tracks its own visibility and time on screen

## Time in seconds this spawn point has been visible
var time_on_screen: float = 0.0
## Whether this spawn point is currently visible
var is_on_screen: bool = false

func _ready() -> void:
	DebugLogger.register_module("VFXSpawnPoint")
	
	# Connect to visibility signals
	screen_entered.connect(_on_screen_entered)
	screen_exited.connect(_on_screen_exited)
	
	# Set detection area
	aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))

func _on_screen_entered() -> void:
	is_on_screen = true
	DebugLogger.debug("VFXSpawnPoint", "%s entered screen" % name)

func _on_screen_exited() -> void:
	is_on_screen = false
	time_on_screen = 0.0  # Reset timer when off screen
	DebugLogger.debug("VFXSpawnPoint", "%s exited screen" % name)

func _process(delta: float) -> void:
	if is_on_screen:
		time_on_screen += delta
