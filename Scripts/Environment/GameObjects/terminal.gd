extends BaseSnappable
class_name Terminal

@export var animation_player: AnimationPlayer
@export var snap_sound: AudioStream

func _ready() -> void:
	# Call parent _ready
	super._ready()
	module_name = "Terminal"
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	

	
	DebugLogger.debug(module_name, "TestSnappable initialized")

# Override the parent method to implement specific behavior
func _on_object_snapped(_object_name: String, _object_node: Node3D) -> void:
	DebugLogger.debug(module_name, "Object snapped to TestSnappable: " + _object_name)
	animation_player.play("drive_insert")
