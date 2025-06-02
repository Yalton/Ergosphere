extends GameObject
class_name BaseSnappable

# Debug properties
@export var enable_debug: bool = true
var module_name: String = "BaseSnappable"

# Snapping control
@export var can_snap: bool = true

var snap_components: Array[SnapComponent] = []

func _ready() -> void:
	# Call parent _ready
	super._ready()
	
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	
	# Find and connect to all snap components
	_find_and_connect_snap_components()
	
	DebugLogger.debug(module_name, "BaseSnappable initialized with " + str(snap_components.size()) + " snap components")

func _find_and_connect_snap_components() -> void:
	# Find all snap components that are children of this node
	snap_components = []
	for child in get_children():
		if child is SnapComponent:
			snap_components.append(child)
			if not child.object_snapped.is_connected(_on_object_snapped):
				child.object_snapped.connect(_on_object_snapped)
				DebugLogger.debug(module_name, "Connected to snap component: " + child.name)

# Virtual method to be overridden by child classes
func _on_object_snapped(_object_name: String, _object_node: Node3D) -> void:
	DebugLogger.debug(module_name, "Object snapped: " + _object_name + ", but no specific behavior implemented in BaseSnappable")
	# This method should be overridden by child classes to implement specific behavior
