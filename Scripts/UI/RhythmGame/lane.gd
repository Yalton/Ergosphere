extends PanelContainer
class_name Lane

## Signal emitted when a note is successfully hit
signal note_hit()

## Signal emitted when a note is missed
signal note_missed()

## Scene to instantiate for notes
@export var note_scene: PackedScene

## The hit zone panel container (child node)
@export var hit_zone_panel: PanelContainer

## Percentage from bottom where hit zone is located (0.0 to 1.0)
@export var hit_zone_position_percent: float = 0.15

## Hit zone size as percentage of lane height
@export var hit_zone_size_percent: float = 0.1

## Lane index (0=A, 1=S, 2=D, 3=F) for note type
@export var lane_index: int = 0

@export_group("Particle Effects")
## Particle effect scene to spawn when a note is hit successfully
@export var hit_particle_scene: PackedScene

## Particle effect scene to spawn when a note is missed
@export var miss_particle_scene: PackedScene

var active_notes: Array[Node] = []
var note_speed: float = 300.0
var spawn_y: float = 0.0
var despawn_y: float = 0.0
var hit_zone_center_y: float = 0.0
var hit_zone_tolerance: float = 0.0

# Add minimum spacing between notes
const MIN_NOTE_SPACING: float = 100.0

func _ready():
	DebugLogger.register_module("Lane")
	# Calculate positions immediately
	_calculate_positions()

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		# Only recalculate if we're not spawning notes
		if active_notes.is_empty():
			call_deferred("_calculate_positions")

func _calculate_positions():
	spawn_y = 0.0
	despawn_y = size.y
	
	# If we have a hit zone panel, use its actual position and size
	if hit_zone_panel and hit_zone_panel.size.y > 0:
		# The hit zone center is the middle of the hit zone panel
		hit_zone_center_y = hit_zone_panel.position.y + (hit_zone_panel.size.y / 2.0)
		# The tolerance is half the height of the hit zone panel
		hit_zone_tolerance = hit_zone_panel.size.y / 2.0
		
		DebugLogger.log_message("Lane", "Lane %d - Using hit_zone_panel: Pos Y=%.1f, Center Y=%.1f, Size=%.1f, Tolerance=%.1f" % 
			[lane_index, hit_zone_panel.position.y, hit_zone_center_y, hit_zone_panel.size.y, hit_zone_tolerance])
	else:
		# Fallback to percentage-based calculation
		hit_zone_center_y = size.y * (1.0 - hit_zone_position_percent)
		hit_zone_tolerance = size.y * hit_zone_size_percent * 0.5
		
		DebugLogger.log_message("Lane", "Lane %d - Using percentages: Center Y=%.1f, Tolerance=%.1f" % 
			[lane_index, hit_zone_center_y, hit_zone_tolerance])
	
	DebugLogger.log_message("Lane", "Lane %d - Size: %.1fx%.1f, Spawn: %.1f, Despawn: %.1f, HitZone: %.1f±%.1f" % 
		[lane_index, size.x, size.y, spawn_y, despawn_y, hit_zone_center_y, hit_zone_tolerance])

func _process(delta):
	# Move all active notes down
	for i in range(active_notes.size() - 1, -1, -1):
		var note = active_notes[i]
		if not is_instance_valid(note):
			active_notes.remove_at(i)
			continue
		
		# Move note down
		note.position.y += note_speed * delta
		
		# Check if note has completely passed the despawn point
		var note_top = note.position.y
		if note_top >= despawn_y:
			DebugLogger.log_message("Lane", "Note despawning - Top: %.1f, Despawn Y: %.1f" % [note_top, despawn_y])
			_despawn_note(i, true)

func can_spawn_note() -> bool:
	# Check if there's enough space from the last spawned note
	if active_notes.is_empty():
		return true
	
	# Get the most recently spawned note (last in array)
	var last_note = active_notes[-1]
	if not is_instance_valid(last_note):
		return true
	
	# Check if the last note has moved far enough down
	var last_note_bottom = last_note.position.y + last_note.size.y
	return last_note_bottom >= MIN_NOTE_SPACING

func spawn_note():
	if not note_scene:
		DebugLogger.log_message("Lane", "No note scene assigned!")
		return
	
	# Check if we can spawn a note
	if not can_spawn_note():
		DebugLogger.log_message("Lane", "Cannot spawn note in lane %d - not enough spacing from previous note" % lane_index)
		return
	
	var note = note_scene.instantiate()
	
	# Add to lane
	add_child(note)
	
	# Position at top center of lane immediately
	var x_pos = size.x / 2.0 - note.size.x / 2.0
	var y_pos = spawn_y
	note.position = Vector2(x_pos, y_pos)
	
	# Set the key type
	if note.has_method("set_key_type"):
		note.call_deferred("set_key_type", lane_index)
	
	# Add to active notes
	active_notes.append(note)
	
	DebugLogger.log_message("Lane", "Spawned note for key %d at Y: %.1f, Total notes in lane: %d" % [lane_index, y_pos, active_notes.size()])

func check_hit():
	# Find the note closest to the hit zone
	var closest_note_index = -1
	var closest_distance = INF
	var closest_note = null
	
	for i in range(active_notes.size()):
		var note = active_notes[i]
		if not is_instance_valid(note):
			continue
			
		var note_center_y = note.position.y + (note.size.y / 2.0)
		var distance = abs(note_center_y - hit_zone_center_y)
		
		# Only consider notes within the hit zone tolerance
		if distance <= hit_zone_tolerance and distance < closest_distance:
			closest_distance = distance
			closest_note_index = i
			closest_note = note
	
	if closest_note_index >= 0:
		# Hit successful - spawn particle effect at note position
		_spawn_particle_effect(hit_particle_scene, closest_note.global_position + closest_note.size / 2.0)
		_despawn_note(closest_note_index, false)
		note_hit.emit()
		DebugLogger.log_message("Lane", "Note hit! Distance: %.1f, Tolerance: %.1f" % [closest_distance, hit_zone_tolerance])
	else:
		DebugLogger.log_message("Lane", "No note in hit zone. Tolerance: %.1f" % hit_zone_tolerance)

func _despawn_note(index: int, missed: bool):
	if index < 0 or index >= active_notes.size():
		return
		
	var note = active_notes[index]
	if not is_instance_valid(note):
		active_notes.remove_at(index)
		return
	
	# Remove from active notes first
	active_notes.remove_at(index)
	
	# Queue free the note
	note.queue_free()
	
	# Emit signal based on whether it was missed
	if missed:
		# Spawn miss particle effect at hit zone
		var miss_pos = Vector2(size.x / 2.0, hit_zone_center_y)
		_spawn_particle_effect(miss_particle_scene, global_position + miss_pos)
		note_missed.emit()

func _spawn_particle_effect(particle_scene: PackedScene, global_pos: Vector2):
	if not particle_scene:
		return
		
	var particles = particle_scene.instantiate()
	get_tree().root.add_child(particles)
	particles.global_position = global_pos
	
	# Auto-remove after 2 seconds
	particles.emitting = true
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()
	
	DebugLogger.log_message("Lane", "Spawned particle effect at position: %v" % global_pos)

func clear_notes():
	for note in active_notes:
		if is_instance_valid(note):
			note.queue_free()
	active_notes.clear()
	DebugLogger.log_message("Lane", "Cleared all notes from lane %d" % lane_index)

func set_note_speed(speed: float):
	note_speed = speed

func get_hit_zone_bounds() -> Dictionary:
	if hit_zone_panel and hit_zone_panel.size.y > 0:
		return {
			"top": hit_zone_panel.position.y,
			"bottom": hit_zone_panel.position.y + hit_zone_panel.size.y,
			"center": hit_zone_center_y,
			"tolerance": hit_zone_tolerance
		}
	else:
		return {
			"top": hit_zone_center_y - hit_zone_tolerance,
			"bottom": hit_zone_center_y + hit_zone_tolerance,
			"center": hit_zone_center_y,
			"tolerance": hit_zone_tolerance
		}
