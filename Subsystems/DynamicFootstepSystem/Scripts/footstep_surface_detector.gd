extends AudioStreamPlayer3D

class_name FootstepSurfaceDetector

@export var generic_fallback_footstep_profile : AudioStreamRandomizer
@export var footstep_material_library : FootstepMaterialLibrary
@export var enable_debug: bool = true
var module_name: String = "FootstepDetector"
var last_result

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	if not generic_fallback_footstep_profile:
		DebugLogger.error(module_name, "No generic fallback footstep profile is assigned")
	else:
		DebugLogger.debug(module_name, "Generic fallback footstep profile assigned")
		
	DebugLogger.debug(module_name, "AudioStreamPlayer3D settings:")
	DebugLogger.debug(module_name, "- Volume: " + str(volume_db) + "db") 
	DebugLogger.debug(module_name, "- Max Distance: " + str(max_distance))
	DebugLogger.debug(module_name, "- Unit Size: " + str(unit_size))
	DebugLogger.debug(module_name, "- Bus: " + str(bus))
	DebugLogger.debug(module_name, "- Global Position: " + str(global_position))
	DebugLogger.debug(module_name, "- Autoplay: " + str(autoplay))

func play_footstep():
	DebugLogger.debug(module_name, "play_footstep() called")
	
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(0, -1, 0))
	DebugLogger.debug(module_name, "Raycasting from " + str(global_position) + " to " + str(global_position + Vector3(0, -1, 0)))
	
	var space_state = get_world_3d().direct_space_state
	if !space_state:
		DebugLogger.error(module_name, "Failed to get space_state")
		return
		
	var result = space_state.intersect_ray(query)
	if result:
		DebugLogger.debug(module_name, "Raycast hit: " + str(result.collider.name if "collider" in result else "none"))
		last_result = result
		
		if _play_by_footstep_surface(result.collider):
			DebugLogger.debug(module_name, "Played footstep by surface")
			return
		elif _play_by_material(result.collider):
			DebugLogger.debug(module_name, "Played footstep by material")
			return
		else:
			DebugLogger.debug(module_name, "No surface or material found, using generic profile")
			_play_footstep(generic_fallback_footstep_profile)
	else:
		DebugLogger.warning(module_name, "Raycast didn't hit anything, no footstep played")

func _play_by_footstep_surface(collider : Node3D) -> bool:
	DebugLogger.debug(module_name, "Checking for footstep surface on " + str(collider.name if collider else "null"))
	
	# Check for footstep surface as a child of the collider
	var footstep_surface_child : AudioStreamRandomizer = _get_footstep_surface_child(collider)
	
	# If a child footstep surface was found, then play the sound defined by it
	if footstep_surface_child:
		DebugLogger.debug(module_name, "Found footstep surface child")
		_play_footstep(footstep_surface_child)
		return true
	
	# Handle footstep surface settings
	elif collider is FootstepSurface and collider.footstep_profile:
		DebugLogger.debug(module_name, "Collider is a FootstepSurface")
		_play_footstep(collider.footstep_profile)
		return true
		
	DebugLogger.debug(module_name, "No footstep surface found")
	return false

func _play_by_material(collider : Node3D) -> bool:
	DebugLogger.debug(module_name, "Checking for material on " + str(collider.name if collider else "null"))
	
	# If no footstep surface, see if we can get a material
	if footstep_material_library:
		DebugLogger.debug(module_name, "Material library found, searching for surface material")
		
		# Find surface material
		var material : Material = _get_surface_material(collider)
		
		# If a material was found
		if material:
			DebugLogger.debug(module_name, "Material found: " + str(material.resource_name))
			
			# Get a profile from our library
			var footstep_profile = footstep_material_library.get_footstep_profile_by_material(material)
			
			# Found profile, use it
			if footstep_profile:
				DebugLogger.debug(module_name, "Found matching footstep profile for material")
				_play_footstep(footstep_profile)
				return true
			else:
				DebugLogger.warning(module_name, "No footstep profile found for material")
		else:
			DebugLogger.warning(module_name, "No material found on collider")
	else:
		DebugLogger.warning(module_name, "No footstep material library assigned")
		
	return false

func _get_footstep_surface_child(collider : Node3D) -> AudioStreamRandomizer:
	# Find all children of the collider that are of type "FootstepSurface"
	var footstep_surfaces = collider.find_children("", "FootstepSurface")
	if footstep_surfaces:
		DebugLogger.debug(module_name, "Found FootstepSurface child: " + str(footstep_surfaces[0].name))
		# Use the first footstep_surface child found
		return footstep_surfaces[0].footstep_profile
		
	return null

func _get_surface_material(collider : Node3D) -> Material:
	var mesh_instance = null
	var meshes = []
	
	if collider is CSGShape3D:
		if collider is CSGCombiner3D:
			DebugLogger.debug(module_name, "Collider is CSGCombiner3D")
			# Composite mesh
			if collider.material_override:
				return collider.material_override
			meshes = collider.get_meshes()
		else:
			DebugLogger.debug(module_name, "Collider is CSGShape3D")
			return collider.material
	elif collider is StaticBody3D or collider is RigidBody3D:
		DebugLogger.debug(module_name, "Collider is StaticBody3D or RigidBody3D")
		# Find the mesh instance to get the material
		if collider.get_parent() is MeshInstance3D:
			mesh_instance = collider.get_parent()
			DebugLogger.debug(module_name, "Found parent MeshInstance3D: " + str(mesh_instance.name))
		else:
			var mesh_instances = collider.find_children("", "MeshInstance3D")
			if mesh_instances:
				if len(mesh_instances) == 1:
					mesh_instance = mesh_instances[0]
					DebugLogger.debug(module_name, "Found single child MeshInstance3D: " + str(mesh_instance.name))
				else:
					meshes = mesh_instances
					DebugLogger.debug(module_name, "Found multiple child MeshInstance3D nodes")
			else:
				DebugLogger.warning(module_name, "No MeshInstance3D found as child or parent")
	
	if meshes:
		DebugLogger.debug(module_name, "Processing meshes array")
		# TODO: Handle multiple meshes
		if len(meshes) > 0:
			mesh_instance = meshes[0]
		
	if mesh_instance and 'mesh' in mesh_instance:
		var mesh = mesh_instance.mesh
		DebugLogger.debug(module_name, "Examining mesh with " + str(mesh.get_surface_count()) + " surfaces")
		
		if mesh.get_surface_count() == 0:
			DebugLogger.warning(module_name, "Mesh has no surfaces")
			return null
		elif mesh.get_surface_count() == 1:
			var material = mesh.surface_get_material(0)
			if material:
				DebugLogger.debug(module_name, "Found material from single surface mesh")
				return material
			else:
				DebugLogger.warning(module_name, "Surface has no material")
		else:
			DebugLogger.debug(module_name, "Mesh has multiple surfaces, detecting which face we're standing on")
			# Complex case with multiple surfaces - continue with existing logic
			var face = null
			
			var ray = last_result['position'] - global_position
			var faces = mesh.get_faces()
			
			var aabb = mesh.get_aabb() as AABB
			var accuracy = round(4*aabb.size.length_squared()) # dynamically calculate a reasonable grid size
			var snap = aabb.size/accuracy # this will be the size of our units to snap to
			
			var coord = null
			
			for i in range(len(faces) / 3):
				# first, figure out what face we're standing on
				var face_idx = i * 3
				var a = mesh_instance.to_global(faces[face_idx])
				var b = mesh_instance.to_global(faces[face_idx+1])
				var c = mesh_instance.to_global(faces[face_idx+2])
				var ray_t = Geometry3D.ray_intersects_triangle(global_position, ray, a, b, c)
				if ray_t:
					face = faces.slice(face_idx, face_idx+3)
					# round out vert coordinates to avoid floating point errors
					coord = [round(faces[face_idx]/snap), round(faces[face_idx+1]/snap), round(faces[face_idx+2]/snap)]
					DebugLogger.debug(module_name, "Found intersecting face")
					break
					
			var mat = null
			if face:
				for surface in range(mesh.get_surface_count()):
					var surf = mesh.surface_get_arrays(surface)[0]
					var has_vert_a = false
					var has_vert_b = false
					var has_vert_c = false
					for vert in surf:
						var vert_coord = round(vert/snap)
						has_vert_a = has_vert_a or vert_coord == coord[0]
						has_vert_b = has_vert_b or vert_coord == coord[1]
						has_vert_c = has_vert_c or vert_coord == coord[2]
						if has_vert_a and has_vert_b and has_vert_c:
							# we found it! note the material and break free!
							mat = mesh.surface_get_material(surface)
							DebugLogger.debug(module_name, "Found material from face detection")
							break
					if has_vert_a and has_vert_b and has_vert_c:
						break
				
				if !mat:
					DebugLogger.warning(module_name, "Found face but couldn't match to a surface material")
			else:
				DebugLogger.warning(module_name, "Couldn't find intersecting face")
				
			return mat
	else:
		DebugLogger.warning(module_name, "No valid mesh found on collision object")
		
	return null

func _play_footstep(footstep_profile : AudioStreamRandomizer):
	if footstep_profile:
		DebugLogger.debug(module_name, "Playing footstep sound")
		stream = footstep_profile
		if !playing:
			play()
		else:
			DebugLogger.debug(module_name, "Already playing a sound")
	else:
		DebugLogger.error(module_name, "Cannot play footstep: footstep_profile is null")
