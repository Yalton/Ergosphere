extends EventHandler
class_name PositionalEventHandler

## Handles all position-based events: warping, spawning, levitating, and throwing objects

# ============== WARP SETTINGS ==============
@export_group("Warp Settings")
## Group name for warp destinations
@export var warp_destination_group: String = "warp_destinations"
## Minimum distance from current position (to ensure noticeable warp)
@export var min_warp_distance: float = 5.0
## Sound to play when warping
@export var warp_sound: AudioStream
## Total duration for the warp effect (should be quick)
@export var warp_total_duration: float = 0.8
## How long to hold the black screen before teleporting (middle of blink)
@export var warp_black_hold: float = 0.1

# ============== SCENE SPAWN SETTINGS ==============
@export_group("Visual Effect Scenes")
## VFX scene for micro_blackhole event
@export var micro_blackhole_scene: PackedScene
## VFX scene for dark_fog event
@export var dark_fog_scene: PackedScene
## VFX scene for entity_appearance event
@export var entity_appearance_scene: PackedScene

@export_group("Spawn Settings")
## Group name for spawn points (all events use same pool)
@export var spawn_group: String = "fx_spawn_points"
## Whether to prefer spawn points closest to player
@export var prefer_closest_to_player: bool = true
## Maximum number of closest points to randomly select from
@export var closest_points_pool_size: int = 3

# ============== ICONOCLAST SPAWN SETTINGS ==============
@export_group("Iconoclast Settings")
## Scene to spawn for iconoclast
@export var iconoclast_scene: PackedScene
## Group name for iconoclast spawn points
@export var iconoclast_spawn_group: String = "iconoclast_spawn"

@export  var iconoclast_spawn_sting: AudioStream
# ============== LEVITATE SETTINGS ==============
@export_group("Levitate Settings")
## Maximum distance to search for objects to levitate
@export var levitate_max_search_distance: float = 10.0
## Upward force to counteract gravity and lift object
@export var lift_force: float = 15.0
## Force to maintain hovering (multiplier on gravity compensation)
@export var hover_force_multiplier: float = 1.1
## Height to levitate object above its starting position
@export var levitate_height: float = 2.0
## Base hold time (seconds) - will be randomized between 5-10
@export var min_hold_time: float = 5.0
@export var max_hold_time: float = 10.0
## Sound to play when object starts levitating
@export var levitate_sound: AudioStream

# ============== THROW SETTINGS ==============
@export_group("Throw Settings")
## Maximum distance to search for objects to throw
@export var throw_max_search_distance: float = 10.0
## Base force multiplier
@export var base_force: float = 5.0
## Maximum force multiplier (applied at max distance)
@export var max_force: float = 15.0
## Sound to play when object is thrown
@export var throw_sound: AudioStream

# State tracking for various events
var spawned_objects: Array[Node] = []
var levitating_body: RigidBody3D = null
var original_gravity_scale: float = 1.0
var start_position: Vector3
var target_height: float
var hold_timer: float = 0.0
var is_levitating: bool = false

func _ready() -> void:
	# All events this consolidated handler processes
	handled_event_ids = [
		"warp", "player_teleport",
		"micro_blackhole", "dark_fog", "entity_appearance", "scene_spawn",
		"spawn_iconoclast",
		"object_levitate",
		"object_throw", "poltergeist"
	]
	
	DebugLogger.register_module("PositionalEventHandler")

func _can_execute_internal() -> Dictionary:
	DebugLogger.log_message("PositionalEventHandler", "Checking if can execute: " + event_data.id)
	
	match event_data.id:
		"warp", "player_teleport":
			return _can_execute_warp()
		"micro_blackhole", "dark_fog", "entity_appearance", "scene_spawn":
			return _can_execute_scene_spawn()
		"spawn_iconoclast":
			return _can_execute_iconoclast_spawn()
		"object_levitate":
			return _can_execute_levitate()
		"object_throw", "poltergeist":
			return _can_execute_throw()
		_:
			return {"success": false, "message": "Unknown event ID: " + event_data.id}

func _execute_internal() -> Dictionary:
	DebugLogger.log_message("PositionalEventHandler", "Executing event: " + event_data.id)
	
	match event_data.id:
		"warp", "player_teleport":
			return _execute_warp()
		"micro_blackhole":
			return _spawn_vfx_scene(micro_blackhole_scene, "micro_blackhole")
		"dark_fog":
			return _spawn_vfx_scene(dark_fog_scene, "dark_fog")
		"entity_appearance":
			return _spawn_vfx_scene(entity_appearance_scene, "entity_appearance")
		"spawn_iconoclast":
			return _execute_iconoclast_spawn()
		"object_levitate":
			return _execute_levitate()
		"object_throw", "poltergeist":
			return _execute_throw()
		_:
			return {"success": false, "message": "Unknown event ID: " + event_data.id}

func _physics_process(delta: float) -> void:
	# Handle ongoing levitation
	if is_levitating and levitating_body:
		_process_levitation(delta)

func end() -> void:
	DebugLogger.log_message("PositionalEventHandler", "Ending event: " + event_data.id)
	
	# Clean up based on event type
	match event_data.id:
		"micro_blackhole", "dark_fog", "entity_appearance", "scene_spawn":
			_cleanup_spawned_objects()
		"object_levitate":
			_end_levitation()
		_:
			pass
	
	# Call base implementation
	super.end()

# ============== WARP EVENT FUNCTIONS ==============
func _can_execute_warp() -> Dictionary:
	var player = CommonUtils.get_player()
	if not player:
		return {"success": false, "message": "No player found in scene"}
	
	var destinations = get_tree().get_nodes_in_group(warp_destination_group)
	if destinations.is_empty():
		return {"success": false, "message": "No warp destinations found in group: " + warp_destination_group}
	
	var has_valid_destination = false
	for dest in destinations:
		if dest is Node3D and dest != player:
			has_valid_destination = true
			break
	
	if not has_valid_destination:
		return {"success": false, "message": "No valid warp destinations (all destinations must be Node3D)"}
	
	return {"success": true, "message": "OK"}

func _execute_warp() -> Dictionary:
	var player = CommonUtils.get_player()
	if not player:
		return {"success": false, "message": "No player found during execution"}
	
	var destination = _find_valid_warp_destination(player)
	if not destination:
		return {"success": false, "message": "No valid warp destination found (check minimum distance requirements)"}
	
	_warp_player_with_vfx(player, destination)
	
	return {"success": true, "message": "OK"}

func _find_valid_warp_destination(player: Node3D) -> Node3D:
	var destinations = get_tree().get_nodes_in_group(warp_destination_group)
	var valid_destinations = []
	
	for dest in destinations:
		if dest is Node3D and dest != player:
			var distance = player.global_position.distance_to(dest.global_position)
			if distance >= min_warp_distance:
				valid_destinations.append(dest)
	
	if valid_destinations.is_empty():
		for dest in destinations:
			if dest is Node3D and dest != player:
				valid_destinations.append(dest)
	
	if valid_destinations.is_empty():
		return null
	
	return valid_destinations[randi() % valid_destinations.size()]

func _warp_player_with_vfx(player: Node3D, destination: Node3D) -> void:
	# Play warp sound if available
	if warp_sound:
		play_audio(warp_sound)
	
	# Try to get the player's VFX component
	var vfx_component = player.get_node_or_null("PlayerVFXComponent")
	if not vfx_component:
		vfx_component = player.vfx_component if "vfx_component" in player else null
	
	# If no player VFX, try global VFX manager
	if not vfx_component:
		vfx_component = get_tree().get_first_node_in_group("visual_effects_manager")
	
	if vfx_component and vfx_component.has_method("invoke_effect"):
		# Calculate timings for a quick blink effect
		var fade_to_black = warp_total_duration * 0.4  # 40% of time fading to black
		var fade_from_black = warp_total_duration * 0.4  # 40% of time fading back
		var black_duration = warp_black_hold  # Hold black briefly
		
		# Start the blink effect with our custom timing
		# Blink effect: startup (fade to black), duration (hold black), winddown (fade from black)
		vfx_component.invoke_effect("blink", fade_to_black, black_duration, fade_from_black)
		
		# Wait for fade to black to complete
		await get_tree().create_timer(fade_to_black).timeout
		
		# Teleport the player while screen is black
		player.global_position = destination.global_position
		if destination.has_method("get_rotation"):
			player.rotation = destination.rotation
		
		# Wait for the rest of the effect to complete
		await get_tree().create_timer(black_duration + fade_from_black).timeout
		
	else:
		# Fallback: No VFX available, just teleport with a small delay
		DebugLogger.warning("PositionalEventHandler", "No VFX component found for blink effect, using instant teleport")
		
		# Small delay for the sound to play
		await get_tree().create_timer(0.1).timeout
		
		player.global_position = destination.global_position
		if destination.has_method("get_rotation"):
			player.rotation = destination.rotation
		
		await get_tree().create_timer(0.2).timeout
	
	# End the event
	if is_active:
		end()

# ============== ICONOCLAST SPAWN EVENT FUNCTIONS ==============
func _can_execute_iconoclast_spawn() -> Dictionary:
	# Check if iconoclast already exists
	var existing_iconoclast = get_tree().get_nodes_in_group("iconoclast")
	if not existing_iconoclast.is_empty():
		return {"success": false, "message": "Iconoclast already exists on the map"}
	
	# Check if scene is configured
	if not iconoclast_scene:
		return {"success": false, "message": "No iconoclast scene configured"}
	
	# Check if spawn points exist
	var spawn_points = get_tree().get_nodes_in_group(iconoclast_spawn_group)
	if spawn_points.is_empty():
		return {"success": false, "message": "No iconoclast spawn points found in group: " + iconoclast_spawn_group}
	
	# Check if player exists to calculate distances
	var player = CommonUtils.get_player()
	if not player:
		return {"success": false, "message": "No player found in scene"}
	
	return {"success": true, "message": "OK"}

func _execute_iconoclast_spawn() -> Dictionary:
	var player = CommonUtils.get_player()
	if not player:
		return {"success": false, "message": "No player found during execution"}
	
	# Get furthest spawn point
	var spawn_point = _find_furthest_spawn_point(player)
	if not spawn_point:
		return {"success": false, "message": "No valid spawn point found"}
	
	# Spawn the iconoclast
	var spawned_instance = iconoclast_scene.instantiate()
	if not spawned_instance:
		return {"success": false, "message": "Failed to instantiate iconoclast scene: " + iconoclast_scene.resource_path}
	
	# Add to scene tree
	get_tree().current_scene.add_child(spawned_instance)
	
	Audio.play_sound(iconoclast_spawn_sting)
	
	# Position the iconoclast
	if spawn_point is Node3D and spawned_instance is Node3D:
		spawned_instance.global_position = spawn_point.global_position
		spawned_instance.global_rotation = spawn_point.global_rotation
	
	# Track the spawned object
	spawned_objects.append(spawned_instance)
	
	# Set up cleanup if the iconoclast has a cleanup signal
	if spawned_instance.has_signal("cleanup_requested"):
		spawned_instance.cleanup_requested.connect(_on_spawned_object_cleanup_requested.bind(spawned_instance))
	
	DebugLogger.log_message("PositionalEventHandler", "Iconoclast spawned at furthest point from player")
	
	return {"success": true, "message": "OK"}

func _find_furthest_spawn_point(player: Node3D) -> Node:
	var spawn_points = get_tree().get_nodes_in_group(iconoclast_spawn_group)
	if spawn_points.is_empty():
		return null
	
	var furthest_point: Node = null
	var furthest_distance: float = 0.0
	
	for point in spawn_points:
		if point is Node3D:
			var distance = player.global_position.distance_to(point.global_position)
			if distance > furthest_distance:
				furthest_distance = distance
				furthest_point = point
	
	return furthest_point

# ============== SCENE SPAWN EVENT FUNCTIONS ==============
func _can_execute_scene_spawn() -> Dictionary:
	match event_data.id:
		"micro_blackhole":
			if not micro_blackhole_scene:
				return {"success": false, "message": "No micro blackhole scene configured"}
		"dark_fog":
			if not dark_fog_scene:
				return {"success": false, "message": "No dark fog scene configured"}
		"entity_appearance":
			if not entity_appearance_scene:
				return {"success": false, "message": "No entity appearance scene configured"}
	
	var spawn_points = get_tree().get_nodes_in_group(spawn_group)
	if spawn_points.is_empty():
		return {"success": false, "message": "No spawn points found in group: " + spawn_group}
	
	return {"success": true, "message": "OK"}

func _spawn_vfx_scene(scene: PackedScene, event_id: String) -> Dictionary:
	if not scene:
		return {"success": false, "message": "No scene configured for " + event_id + " event"}
	
	var spawn_points = get_tree().get_nodes_in_group(spawn_group)
	if spawn_points.is_empty():
		return {"success": false, "message": "No spawn points found in group: " + spawn_group}
	
	var player = CommonUtils.get_player()
	
	var offscreen_points = []
	for point in spawn_points:
		if point.has_method("is_on_screen") and not point.is_on_screen:
			offscreen_points.append(point)
		else:
			offscreen_points.append(point)
	
	if offscreen_points.is_empty():
		offscreen_points = spawn_points
	
	var spawn_point: Node
	if prefer_closest_to_player and player and player is Node3D:
		spawn_point = _get_closest_spawn_point(offscreen_points, player)
	else:
		spawn_point = offscreen_points[randi() % offscreen_points.size()]
	
	return _spawn_scene_at_location(scene, spawn_point, event_id)

func _get_closest_spawn_point(points: Array, player: Node3D) -> Node:
	if points.is_empty():
		return null
	
	var distances = []
	for point in points:
		if point is Node3D:
			var distance = point.global_position.distance_to(player.global_position)
			distances.append({"point": point, "distance": distance})
	
	distances.sort_custom(func(a, b): return a.distance < b.distance)
	
	var pool_size = min(closest_points_pool_size, distances.size())
	var selected_index = randi() % pool_size
	
	return distances[selected_index].point

func _spawn_scene_at_location(scene: PackedScene, spawn_point: Node, event_id: String) -> Dictionary:
	if not spawn_point:
		return {"success": false, "message": "Invalid spawn point for " + event_id + " event"}
	
	var spawned_instance = scene.instantiate()
	if not spawned_instance:
		return {"success": false, "message": "Failed to instantiate " + event_id + " scene: " + scene.resource_path}
	
	spawn_point.add_child(spawned_instance)
	
	if spawn_point is Node3D and spawned_instance is Node3D:
		spawned_instance.global_position = spawn_point.global_position
		spawned_instance.global_rotation = spawn_point.global_rotation
	
	spawned_objects.append(spawned_instance)
	
	if spawned_instance.has_signal("cleanup_requested"):
		spawned_instance.cleanup_requested.connect(_on_spawned_object_cleanup_requested.bind(spawned_instance))
	
	if not spawned_instance.has_method("handle_own_cleanup"):
		var cleanup_timer = get_tree().create_timer(30.0)
		cleanup_timer.timeout.connect(_cleanup_specific_object.bind(spawned_instance))
	
	return {"success": true, "message": "OK"}

func _on_spawned_object_cleanup_requested(spawned_object: Node) -> void:
	_cleanup_specific_object(spawned_object)

func _cleanup_specific_object(spawned_object: Node) -> void:
	if not is_instance_valid(spawned_object):
		return
	
	if spawned_object in spawned_objects:
		spawned_objects.erase(spawned_object)
	
	spawned_object.queue_free()

func _cleanup_spawned_objects() -> void:
	for spawned_object in spawned_objects:
		if is_instance_valid(spawned_object):
			spawned_object.queue_free()
	
	spawned_objects.clear()

# ============== LEVITATE EVENT FUNCTIONS ==============
func _can_execute_levitate() -> Dictionary:
	var player = CommonUtils.get_player()
	if not player:
		return {"success": false, "message": "No player found in scene"}
	
	var closest_body = _find_closest_rigidbody(player.global_position, levitate_max_search_distance)
	if not closest_body:
		return {"success": false, "message": "No rigidbody found within " + str(levitate_max_search_distance) + " units"}
	
	return {"success": true, "message": "OK"}

func _execute_levitate() -> Dictionary:
	var player = CommonUtils.get_player()
	if not player:
		return {"success": false, "message": "No player found during execution"}
	
	var closest_body = _find_closest_rigidbody(player.global_position, levitate_max_search_distance)
	if not closest_body:
		return {"success": false, "message": "No rigidbody found to levitate"}
	
	levitating_body = closest_body
	start_position = levitating_body.global_position
	target_height = start_position.y + levitate_height
	
	original_gravity_scale = levitating_body.gravity_scale
	
	hold_timer = randf_range(min_hold_time, max_hold_time)
	
	if levitate_sound:
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.stream = levitate_sound
		audio_player.bus = "SFX"
		audio_player.max_distance = 20.0
		get_tree().current_scene.add_child(audio_player)
		audio_player.global_position = levitating_body.global_position
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)
	
	# Trigger chromatic aberration and edge detection VFX
	_trigger_psychic_vfx()
	
	is_levitating = true
	
	return {"success": true, "message": "OK"}

func _process_levitation(delta: float) -> void:
	var gravity_force = ProjectSettings.get_setting("physics/3d/default_gravity") * levitating_body.mass
	var current_height = levitating_body.global_position.y
	
	var height_difference = target_height - current_height
	var vertical_force = gravity_force * hover_force_multiplier
	
	if height_difference > 0.1:
		vertical_force += lift_force * clamp(height_difference, 0.0, 1.0)
	
	levitating_body.apply_central_force(Vector3.UP * vertical_force)
	
	var current_velocity = levitating_body.linear_velocity
	current_velocity.x *= 0.9
	current_velocity.z *= 0.9
	levitating_body.linear_velocity = current_velocity
	
	hold_timer -= delta
	if hold_timer <= 0:
		end()

func _end_levitation() -> void:
	if levitating_body:
		levitating_body.gravity_scale = original_gravity_scale
		
		levitating_body = null
	
	is_levitating = false

# ============== THROW EVENT FUNCTIONS ==============
func _can_execute_throw() -> Dictionary:
	var player = CommonUtils.get_player()
	if not player:
		return {"success": false, "message": "No player found in scene"}
	
	var closest_body = _find_closest_rigidbody(player.global_position, throw_max_search_distance)
	if not closest_body:
		return {"success": false, "message": "No rigidbody found within " + str(throw_max_search_distance) + " units"}
	
	return {"success": true, "message": "OK"}

func _execute_throw() -> Dictionary:
	var player = CommonUtils.get_player()
	if not player:
		return {"success": false, "message": "No player found during execution"}
	
	var closest_body = _find_closest_rigidbody(player.global_position, throw_max_search_distance)
	if not closest_body:
		return {"success": false, "message": "No rigidbody found to throw"}
	
	_throw_object_at_player(closest_body, player.global_position)
	
	# Trigger chromatic aberration and edge detection VFX for psychic throw
	_trigger_psychic_vfx()
	
	get_tree().create_timer(1.0).timeout.connect(func(): 
		if is_active:
			end()
	)
	
	return {"success": true, "message": "OK"}

func _throw_object_at_player(body: RigidBody3D, player_pos: Vector3) -> void:
	var object_pos = body.global_position
	var distance = object_pos.distance_to(player_pos)
	
	var force_multiplier = lerp(base_force, max_force, distance / throw_max_search_distance)
	
	var throw_direction = (player_pos - object_pos).normalized()
	throw_direction.y += 0.3
	throw_direction = throw_direction.normalized()
	
	var force_vector = throw_direction * force_multiplier
	body.apply_central_impulse(force_vector)
	
	if throw_sound:
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.stream = throw_sound
		audio_player.bus = "SFX"
		audio_player.max_distance = 20.0
		get_tree().current_scene.add_child(audio_player)
		audio_player.global_position = object_pos
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)

# ============== SHARED UTILITY FUNCTIONS ==============
func _find_closest_rigidbody(player_pos: Vector3, max_distance: float) -> RigidBody3D:
	var closest_body: RigidBody3D = null
	var closest_distance: float = max_distance
	
	var bodies = get_tree().get_nodes_in_group("game_object")
	if bodies.is_empty():
		bodies = _find_all_rigidbodies()
	
	for body in bodies:
		if body is RigidBody3D:
			var distance = player_pos.distance_to(body.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_body = body
	
	return closest_body

func _find_all_rigidbodies() -> Array:
	var bodies = []
	_recursive_find_rigidbodies(get_tree().root, bodies)
	return bodies

func _recursive_find_rigidbodies(node: Node, bodies: Array) -> void:
	if node is RigidBody3D:
		bodies.append(node)
	
	for child in node.get_children():
		_recursive_find_rigidbodies(child, bodies)

# ============== VFX TRIGGER FUNCTIONS ==============
func _trigger_psychic_vfx() -> void:
	"""Trigger chromatic aberration and edge detection for psychic events"""
	var player = CommonUtils.get_player()
	if not player:
		return
	
	# Try to get VFX component (player or global)
	var vfx_component = player.get_node_or_null("PlayerVFXComponent")
	if not vfx_component:
		vfx_component = player.vfx_component if "vfx_component" in player else null
	if not vfx_component:
		vfx_component = get_tree().get_first_node_in_group("visual_effects_manager")
	
	if vfx_component and vfx_component.has_method("invoke_effect"):
		# Random duration between 2-5 seconds
		var effect_duration = randf_range(2.0, 5.0)
		
		# Quick startup and winddown for sudden psychic manifestation
		var startup = 0.2
		var winddown = 0.3
		
		# Trigger both effects simultaneously
		vfx_component.invoke_effect("chromatic_aberration", startup, effect_duration, winddown)
		vfx_component.invoke_effect("edge_detection", startup, effect_duration, winddown)
		
		DebugLogger.debug("PositionalEventHandler", "Triggered psychic VFX for %.1fs" % effect_duration)
	else:
		DebugLogger.warning("PositionalEventHandler", "No VFX component found for psychic effects")
