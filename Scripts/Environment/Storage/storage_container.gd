# StorageContainer.gd  
extends ContainerInteractable
class_name StorageContainer

## Node where items get instantiated
@export var item_spawn_point: Node3D

## Mesh instance for the emissive material
@export var emissive_mesh: MeshInstance3D

## Interaction area that detects player interaction and item presence
@export var interaction_area: Area3D

## Time to wait after item removal before auto-closing (seconds)
@export var auto_close_delay: float = 1.0

# Container state
var is_locked: bool = true
var contained_item: Node3D = null
var original_emissive_material: Material = null
var auto_close_timer: Timer
var interaction_forwarder: Node3D = null

func _ready() -> void:
	super._ready()
	
	# Create auto-close timer
	auto_close_timer = Timer.new()
	auto_close_timer.one_shot = true
	auto_close_timer.timeout.connect(_on_auto_close_timeout)
	add_child(auto_close_timer)
	
	# Start locked
	set_locked(true)
	
	# Find components if not assigned
	if not item_spawn_point:
		item_spawn_point = find_child("ItemSpawnPoint", true)
	
	if not emissive_mesh:
		emissive_mesh = find_child("EmissiveMesh", true)
		
	if not interaction_area:
		# Try to find it through InteractionForwarder
		interaction_forwarder = find_child("InteractionForwarder", true)
		if interaction_forwarder:
			for child in interaction_forwarder.get_children():
				if child is Area3D:
					interaction_area = child
					break
	
	# Connect area signals if we found it
	if interaction_area:
		interaction_area.body_exited.connect(_on_body_exited)
	
	# Store original emissive material
	if emissive_mesh:
		if emissive_mesh.get_surface_override_material(0):
			original_emissive_material = emissive_mesh.get_surface_override_material(0)
		elif emissive_mesh.material_override:
			original_emissive_material = emissive_mesh.material_override
		elif emissive_mesh.mesh and emissive_mesh.mesh.surface_get_material(0):
			original_emissive_material = emissive_mesh.mesh.surface_get_material(0)
	
	DebugLogger.debug(module_name, "StorageContainer initialized")

func interact(player_interaction: PlayerInteractionComponent) -> void:
	# Can only interact if unlocked and not already open
	if is_locked:
		DebugLogger.debug(module_name, "Interaction blocked - container is locked")
		return
		
	if is_open:
		DebugLogger.debug(module_name, "Container already open")
		return
	
	# Open the container
	open_container()
	
	# Disable the interaction area to prevent blocking item pickup
	_disable_interaction_area()

func _disable_interaction_area() -> void:
	if interaction_area:
		interaction_area.monitoring = false
		interaction_area.monitorable = false
		interaction_area.input_ray_pickable = false
		interaction_area.collision_layer = 24
		interaction_area.collision_mask = 24
		DebugLogger.debug(module_name, "Disabled interaction area")
	
	# Also disable the interaction forwarder if it exists
	if interaction_forwarder:
		interaction_forwarder.set_process_mode(Node.PROCESS_MODE_DISABLED)

func _enable_interaction_area() -> void:
	if interaction_area:
		interaction_area.monitoring = true
		interaction_area.monitorable = true
		interaction_area.input_ray_pickable = true
		interaction_area.collision_layer = 2
		interaction_area.collision_mask = 2
		DebugLogger.debug(module_name, "Enabled interaction area")
	
	# Re-enable the interaction forwarder
	if interaction_forwarder:
		interaction_forwarder.set_process_mode(Node.PROCESS_MODE_INHERIT)

## Called when container opening animation completes
func _complete_open() -> void:
	super._complete_open()

	# Reparent the item to props so it doesn't move with container
	_reparent_to_props()
	
	# Start monitoring for item removal
	_start_item_monitoring()

func _start_item_monitoring() -> void:
	# Check if item still exists every frame while open
	set_process(true)

## Reparent item to props group while maintaining global transform
func _reparent_to_props() -> void:
	if not contained_item or not is_instance_valid(contained_item):
		return
	
	# Get the props node from global group
	var props_nodes = get_tree().get_nodes_in_group("props")
	if props_nodes.is_empty():
		DebugLogger.error(module_name, "No node found in 'props' group")
		return
	
	var props_node = props_nodes[0]
	if not props_node is Node3D:
		DebugLogger.error(module_name, "Props node is not a Node3D")
		return
	
	# Store global transform before reparenting
	var local_transform = contained_item.global_transform
	
	# Reparent to props node
	contained_item.get_parent().remove_child(contained_item)
	props_node.add_child(contained_item)
	
	# Restore global transform
	contained_item.global_transform = local_transform
	
	DebugLogger.debug(module_name, "Item reparented to props group")
	
func _process(_delta: float) -> void:
	# Only process if container is open and we had an item
	if is_open and contained_item != null:
		# Check if item is still valid and inside container
		if not is_instance_valid(contained_item) or not _is_item_inside():
			DebugLogger.debug(module_name, "Item removed from container")
			contained_item = null
			
			# Stop processing and start auto-close timer
			set_process(false)
			auto_close_timer.start(auto_close_delay)

func _is_item_inside() -> bool:
	if not contained_item or not interaction_area:
		return false
	
	# Check if the item is still a child of our spawn point
	#if item_spawn_point and contained_item.get_parent() != item_spawn_point:
		#return false
		
	# Alternative: Check distance from spawn point
	if item_spawn_point:
		var distance = contained_item.global_position.distance_to(item_spawn_point.global_position)
		if distance > 1.5:  # Threshold for "removed"
			return false
	
	return true

func _on_body_exited(body: Node3D) -> void:
	# Check if the exited body is our contained item
	if body == contained_item and is_open:
		DebugLogger.debug(module_name, "Contained item exited area")
		# Item might be getting picked up, but let _process handle the actual detection

func _on_auto_close_timeout() -> void:
	# Double check that container is still empty
	if is_empty() and is_open:
		DebugLogger.debug(module_name, "Auto-closing empty container")
		close_container()
		
		# Re-lock the container
		set_locked(true)
		
		# Re-enable interaction area
		_enable_interaction_area()

## Load an item into this container
func load_item(scene_path: String) -> bool:
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		var item_scene = load(scene_path)
		if item_scene:
			contained_item = item_scene.instantiate()
			if item_spawn_point:
				item_spawn_point.add_child(contained_item)
			else:
				add_child(contained_item)
			
			# Unlock the container and turn on emissive
			set_locked(false)
			
			DebugLogger.info(module_name, "Loaded item from: " + scene_path)
			return true
	
	DebugLogger.error(module_name, "Failed to load item from: " + scene_path)
	return false

## Remove the contained item
func remove_item() -> Node3D:
	if contained_item and is_instance_valid(contained_item):
		var item = contained_item
		contained_item = null
		
		# Remove from scene tree but don't free it
		if item.get_parent():
			item.get_parent().remove_child(item)
		
		DebugLogger.debug(module_name, "Item removed from container")
		return item
	return null

## Check if container is empty
func is_empty() -> bool:
	return contained_item == null or not is_instance_valid(contained_item)

## Set locked/unlocked state
func set_locked(locked: bool) -> void:
	is_locked = locked
	
	# Update emissive material
	if emissive_mesh:
		var material = emissive_mesh.get_active_material(2)
		if material and material is StandardMaterial3D:
			material.emission_enabled = not locked
			emissive_mesh.set_surface_override_material(2, material)
			DebugLogger.debug(module_name, "Set emission enabled: " + str(not locked))
	
	DebugLogger.debug(module_name, "Container " + ("locked" if locked else "unlocked"))

## Override interaction text
func get_interaction_text() -> String:
	if is_locked:
		return "Locked"
	elif is_animating:
		return "Please wait..."
	elif is_open:
		return ""  # No text when open to avoid confusion
	else:
		return "Open " + display_name

## Reset container to initial state
func reset_container() -> void:
	# Stop any timers
	auto_close_timer.stop()
	set_process(false)
	
	# Remove any remaining item
	if contained_item:
		remove_item()
	
	# Close if open
	if is_open:
		is_open = false
		is_animating = false
	
	# Lock and disable emission
	set_locked(true)
	
	# Enable interaction area
	_enable_interaction_area()
	
	DebugLogger.debug(module_name, "Container reset to initial state")
