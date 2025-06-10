# StorageContainer.gd  
extends ContainerInteractable
class_name StorageContainer

## Node where items get instantiated
@export var item_spawn_point: Node3D

## Mesh instance for the emissive material
@export var emissive_mesh: MeshInstance3D

# Container state
var is_locked: bool = true
var contained_item: Node3D = null
var original_emissive_material: Material = null

func _ready() -> void:
	super._ready()
	
	# Start locked
	set_locked(true)
	
	# Find item spawn point if not assigned
	if not item_spawn_point:
		item_spawn_point = find_child("ItemSpawnPoint", true)
	
	# Find emissive mesh if not assigned
	if not emissive_mesh:
		emissive_mesh = find_child("EmissiveMesh", true)
	
	# Store original emissive material
	if emissive_mesh and emissive_mesh.get_surface_override_material(0):
		original_emissive_material = emissive_mesh.get_surface_override_material(0)
	elif emissive_mesh and emissive_mesh.material_override:
		original_emissive_material = emissive_mesh.material_override
	elif emissive_mesh and emissive_mesh.mesh and emissive_mesh.mesh.surface_get_material(0):
		original_emissive_material = emissive_mesh.mesh.surface_get_material(0)
	
	DebugLogger.debug(module_name, "StorageContainer initialized")

func interact(player_interaction: PlayerInteractionComponent) -> void:
	# Can only interact if unlocked
	if is_locked:
		DebugLogger.debug(module_name, "Interaction blocked - container is locked")
		return
	
	# Use parent interaction behavior
	super.interact(player_interaction)

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
			
			# Unlock the container
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
		if locked:
			# Make it black - create a duplicate material and set emission to black
			if original_emissive_material:
				var black_material = original_emissive_material.duplicate()
				if black_material.has_method("set_emission"):
					black_material.set_emission(Color.BLACK)
				elif black_material.has_method("set_albedo"):
					black_material.set_albedo(Color.BLACK)
				emissive_mesh.material_override = black_material
		else:
			# Restore original green material
			if original_emissive_material:
				emissive_mesh.material_override = original_emissive_material
			else:
				emissive_mesh.material_override = null
	
	DebugLogger.debug(module_name, "Container " + ("locked" if locked else "unlocked"))

## Override close behavior to lock and remove item
func _complete_close() -> void:
	super._complete_close()
	
	# If container had an item, remove it and lock container
	if not is_empty():
		remove_item()
		set_locked(true)
		DebugLogger.debug(module_name, "Container closed, item removed, container locked")

## Override interaction text
func get_interaction_text() -> String:
	if is_locked:
		return "Locked"
	elif is_animating:
		return "Please wait..."
	elif is_open:
		return "Close " + display_name
	else:
		return "Open " + display_name
