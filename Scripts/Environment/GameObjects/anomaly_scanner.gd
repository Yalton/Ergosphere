# ProximityTracker.gd
extends AwareGameObject
class_name ProximityTracker

## Group name to find tracking points from
@export var tracking_group: String = "anomalous_hotspots"

## Maximum distance for detection (200m default)
@export var max_detection_distance: float = 200.0

## Distance within which tracking completes
@export var completion_distance: float = 2.0

## Audio player for beeping sounds
@export var audio_player: AudioStreamPlayer3D

## Beep sound to play
@export var beep_sound: AudioStream

## OmniLight to flash
@export var flash_light: OmniLight3D

## MeshInstance3D to create emissive material for
@export var emissive_mesh: MeshInstance3D

## Emission color for the material
@export var emission_color: Color = Color.RED

## Base beep interval in seconds (slowest rate)
@export var base_beep_interval: float = 2.0

## Fastest beep interval in seconds
@export var fastest_beep_interval: float = 0.1

## Flash duration in seconds
@export var flash_duration: float = 0.2

## Path to the shattered scanner scene
@export var shattered_scanner_scene: PackedScene

## Sound to play on safe completion (day 2)
@export var safe_completion_sound: AudioStream

## Sound to play on explosion (day 4)
@export var unsafe_completion_sound: AudioStream

# Internal state
var target_point: Node3D
var beep_timer: Timer
var flash_tween: Tween
var emissive_material: StandardMaterial3D
var original_emission_energy: float = 0.0
var is_tracking: bool = false
var is_completed: bool = false
var carryable_component: CarryableComponent

func _ready() -> void:
	super._ready()
	module_name = "ProximityTracker"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Get CarryableComponent reference
	carryable_component = find_child("CarryableComponent", true, false)
	if not carryable_component:
		DebugLogger.error(module_name, "No CarryableComponent found!")
	
	# Get tracking points from group
	var tracking_points = get_tree().get_nodes_in_group(tracking_group)
	if tracking_points.is_empty():
		DebugLogger.error(module_name, "No nodes found in group: " + tracking_group)
		return
	
	# Setup beep timer
	beep_timer = Timer.new()
	beep_timer.one_shot = true
	beep_timer.timeout.connect(_trigger_beep_flash)
	add_child(beep_timer)
	
	# Create emissive material for mesh
	if emissive_mesh:
		_create_emissive_material()
	else:
		DebugLogger.error(module_name, "No emissive mesh assigned!")
		return
	
	# Choose random target and start tracking
	_choose_random_target(tracking_points)
	
	DebugLogger.debug(module_name, "Proximity tracker initialized")

func _create_emissive_material() -> void:
	# Create new emissive material
	emissive_material = StandardMaterial3D.new()
	emissive_material.emission_enabled = true
	emissive_material.emission = emission_color
	emissive_material.emission_energy_multiplier = original_emission_energy
	
	# Set as override material
	emissive_mesh.material_override = emissive_material
	
	DebugLogger.debug(module_name, "Created emissive material with color: " + str(emission_color))

func _choose_random_target(tracking_points: Array) -> void:
	if tracking_points.is_empty():
		return
		
	target_point = tracking_points[randi() % tracking_points.size()]
	is_tracking = true
	is_completed = false
	
	# Start first beep
	_update_beep_rate()
	
	DebugLogger.info(module_name, "Now tracking: " + target_point.name)

func _process(_delta: float) -> void:
	if not is_tracking or is_completed:
		return
		
	var distance = global_position.distance_to(target_point.global_position)
	
	# Check for completion
	if distance <= completion_distance:
		_complete_tracking()
		return
	
	# Update beep rate based on distance
	if beep_timer.is_stopped():
		_update_beep_rate()

func _update_beep_rate() -> void:
	if not target_point:
		return
		
	var distance = global_position.distance_to(target_point.global_position)
	distance = clamp(distance, completion_distance, max_detection_distance)
	
	# Exponential scaling - closer = faster beeping
	var distance_ratio = (max_detection_distance - distance) / (max_detection_distance - completion_distance)
	distance_ratio = pow(distance_ratio, 2)  # Exponential curve
	
	var beep_interval = lerp(base_beep_interval, fastest_beep_interval, distance_ratio)
	beep_timer.start(beep_interval)
	
	#DebugLogger.debug(module_name, "Distance: %.1f, Beep interval: %.2f" % [distance, beep_interval])

func _trigger_beep_flash() -> void:
	if is_completed:
		return
		
	# Play beep sound
	if audio_player and beep_sound:
		audio_player.stream = beep_sound
		audio_player.play()
	
	# Flash light and material
	_flash_visual_elements()

func _flash_visual_elements() -> void:
	# Kill existing tween
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
	
	# Create new flash tween
	flash_tween = create_tween()
	flash_tween.set_parallel(true)
	
	# Flash the light
	if flash_light:
		flash_light.visible = true
		flash_tween.tween_callback(func(): flash_light.visible = false).set_delay(flash_duration)
	
	# Flash the emissive material
	if emissive_material:
		emissive_material.emission_energy_multiplier = 1.0
		flash_tween.tween_property(emissive_material, "emission_energy_multiplier", 
			original_emission_energy, flash_duration)

func _complete_tracking() -> void:
	is_tracking = false
	is_completed = true
	
	# Stop beep timer
	beep_timer.stop()
	
	var current_day = GameManager.current_day
	DebugLogger.info(module_name, "Completing tracking on day: " + str(current_day))
	
	# Day 2: Safe completion with blinks
	if current_day == 2:
		_safe_completion()
	# Day 4: Explosive completion
	elif current_day == 4:
		_explosive_completion()
	else:
		# Default to safe for other days
		_safe_completion()
	
	# Complete task regardless
	if task_aware_component:
		task_aware_component.complete_task()
	
	DebugLogger.info(module_name, "Tracking completed at target: " + target_point.name)

func _safe_completion() -> void:
	DebugLogger.info(module_name, "Safe completion - blinking sequence")
	
	# Play completion sound
	if safe_completion_sound:
		Audio.play_sound(safe_completion_sound)
	
	# Create blinking sequence - 6 blinks in 2 seconds
	var blink_tween = create_tween()
	var blink_duration = 0.15  # Each blink takes 0.15 seconds
	var blink_gap = 0.18  # Gap between blinks
	
	for i in range(6):
		# Turn on
		blink_tween.tween_callback(func():
			if flash_light:
				flash_light.visible = true
			if emissive_material:
				emissive_material.emission_energy_multiplier = 1.0
		)
		
		# Turn off after blink_duration
		blink_tween.tween_interval(blink_duration)
		blink_tween.tween_callback(func():
			if flash_light:
				flash_light.visible = false
			if emissive_material:
				emissive_material.emission_energy_multiplier = original_emission_energy
		)
		
		# Wait before next blink (except after last one)
		if i < 5:
			blink_tween.tween_interval(blink_gap)

func _explosive_completion() -> void:
	DebugLogger.info(module_name, "Explosive completion - scanner will explode")
	
	# Force drop if being carried
	if carryable_component and carryable_component.is_being_carried:
		DebugLogger.info(module_name, "Forcing player to drop scanner before explosion")
		carryable_component.leave()
	
	# Play explosion sound
	if unsafe_completion_sound:
		Audio.play_sound(unsafe_completion_sound)
	
	# Trigger iconoclast spawn event
	GameManager.event_manager.trigger_event("spawn_iconoclast")
	DebugLogger.info(module_name, "Triggered iconoclast spawn event")
	
	# Spawn shattered scanner and self-destruct
	_spawn_shattered_scanner()

func _spawn_shattered_scanner() -> void:
	if not shattered_scanner_scene:
		DebugLogger.error(module_name, "No shattered scanner scene assigned!")
		queue_free()
		return
	
	# Instance the shattered scanner
	var shattered_scanner : ShatteredObject = shattered_scanner_scene.instantiate()
	
	var props_node = get_tree().get_first_node_in_group("props")
	if props_node: 
		props_node.add_child(shattered_scanner)
		
		shattered_scanner.initialize(global_position, global_rotation)
		
		DebugLogger.info(module_name, "Spawning shatter scene at " + str(global_position))

		# Add to the same parent
		DebugLogger.info(module_name, "Spawned shattered scanner")
	else: 
		DebugLogger.error(module_name, "Props container node not found")
		return
	

	
	# Remove ourselves
	queue_free()

## Reset the tracker to choose a new target
func reset_tracking() -> void:
	is_tracking = false
	is_completed = false
	
	# Turn off visuals
	if flash_light:
		flash_light.visible = false
	
	if emissive_material:
		emissive_material.emission_energy_multiplier = original_emission_energy
	
	# Choose new target
	var tracking_points = get_tree().get_nodes_in_group(tracking_group)
	if not tracking_points.is_empty():
		_choose_random_target(tracking_points)
	
	DebugLogger.debug(module_name, "Tracking reset")

## Get current distance to target for debugging
func get_distance_to_target() -> float:
	if target_point:
		return global_position.distance_to(target_point.global_position)
	return -1.0
