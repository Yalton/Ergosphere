extends BaseSnappable
class_name TestSnappable

@export var sphere_mesh: MeshInstance3D
@export var snap_sound: AudioStream


func _ready() -> void:
	# Call parent _ready
	super._ready()
	module_name = "TestSnappable"
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	
	# Make sure the sphere mesh is hidden initially
	if sphere_mesh:
		sphere_mesh.visible = false
	else:
		DebugLogger.error(module_name, "No sphere mesh assigned to TestSnappable")
	
	DebugLogger.debug(module_name, "TestSnappable initialized")

# Override the parent method to implement specific behavior
func _on_object_snapped(object_name: String, object_node: Node3D) -> void:
	DebugLogger.debug(module_name, "Object snapped to TestSnappable: " + object_name)
	
	# Show the sphere mesh
	if sphere_mesh:
		sphere_mesh.visible = true
		DebugLogger.debug(module_name, "Showing sphere mesh")
	
	# Play snap sound if we have one
	if snap_sound:
		Audio.play_sound_3d(snap_sound).global_position = global_position
		DebugLogger.debug(module_name, "Playing snap sound")
