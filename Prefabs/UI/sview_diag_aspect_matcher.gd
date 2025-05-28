@tool
extends SubViewport
class_name ViewportAspectMatcher

## The display mesh to match aspect ratio with
@export var display_mesh: MeshInstance3D:
	set(value):
		display_mesh = value
		if Engine.is_editor_hint():
			call_deferred("_update_viewport_size")

## Base width for the viewport (performance consideration)
@export var base_width: int = 640:
	set(value):
		base_width = max(1, value)
		if Engine.is_editor_hint():
			call_deferred("_update_viewport_size")

## Enable automatic aspect ratio matching
@export var auto_match_aspect: bool = true:
	set(value):
		auto_match_aspect = value
		if Engine.is_editor_hint() and value:
			call_deferred("_update_viewport_size")

## Manual trigger to update viewport size
@export var update_size: bool = false:
	set(value):
		if Engine.is_editor_hint() and value:
			call_deferred("_update_viewport_size")
			# Use call_deferred to reset the button
			call_deferred("set", "update_size", false)

func _ready() -> void:
	# Only run the tool script logic in editor
	if Engine.is_editor_hint():
		# Update size when the node is ready
		if auto_match_aspect:
			call_deferred("_update_viewport_size")

func _update_viewport_size() -> void:
	# Only run in editor
	if not Engine.is_editor_hint():
		return
		
	# Check if we have a valid mesh reference
	if not display_mesh or not display_mesh.mesh:
		push_warning("ViewportAspectMatcher: No display mesh assigned or mesh is null")
		return
	
	# Get mesh dimensions
	var mesh_size = Vector2.ONE
	
	if display_mesh.mesh is QuadMesh:
		var quad_mesh = display_mesh.mesh as QuadMesh
		mesh_size = quad_mesh.size
	elif display_mesh.mesh is PlaneMesh:
		var plane_mesh = display_mesh.mesh as PlaneMesh
		mesh_size = plane_mesh.size
	else:
		push_warning("ViewportAspectMatcher: Display mesh must be QuadMesh or PlaneMesh")
		return
	
	# Make sure we have valid dimensions
	if mesh_size.x <= 0 or mesh_size.y <= 0:
		push_warning("ViewportAspectMatcher: Invalid mesh size: " + str(mesh_size))
		return
	
	# Calculate aspect ratio from mesh
	var aspect_ratio = mesh_size.x / mesh_size.y
	
	# Calculate new viewport height based on base width and aspect ratio
	var new_height = float(base_width) / aspect_ratio
	
	# Round up to ensure whole pixels
	var final_height = int(ceil(new_height))
	
	# Update viewport size
	var new_size = Vector2i(base_width, final_height)
	
	# Only update if size actually changed
	if size != new_size:
		size = new_size
		
		# Force the property to update in the inspector
		notify_property_list_changed()
		
		# Log the change
		print("ViewportAspectMatcher: Updated viewport size to ", size, " to match mesh aspect ratio ", aspect_ratio)
		print("  Mesh size: ", mesh_size)
		print("  Calculated height: ", new_height, " -> ", final_height)

# Override notification to detect when the scene is saved
func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		match what:
			NOTIFICATION_POST_ENTER_TREE:
				# Update when added to scene
				if auto_match_aspect:
					call_deferred("_update_viewport_size")
			
			NOTIFICATION_EDITOR_PRE_SAVE:
				# Update right before saving
				if auto_match_aspect:
					_update_viewport_size()

# Override to ensure the viewport updates when entering the editor
func _enter_tree() -> void:
	if Engine.is_editor_hint() and auto_match_aspect:
		call_deferred("_update_viewport_size")

# Debug function to manually trigger from the editor
func force_update() -> void:
	if Engine.is_editor_hint():
		print("ViewportAspectMatcher: Force update requested")
		_update_viewport_size()
