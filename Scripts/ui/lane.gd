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

var active_notes: Array[Node] = []
var note_speed: float = 300.0
var spawn_y: float = 0.0
var despawn_y: float = 0.0
var hit_zone_center_y: float = 0.0
var hit_zone_tolerance: float = 0.0

func _ready():
	DebugLogger.register_module("Lane")
	_calculate_positions()
	
	# Position hit zone panel if it exists
	if hit_zone_panel:
		var hit_zone_y = size.y * (1.0 - hit_zone_position_percent) - (hit_zone_panel.size.y / 2.0)
		hit_zone_panel.position.y = hit_zone_y

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_calculate_positions()

func _calculate_positions():
	spawn_y = 0.0
	despawn_y = size.y
	hit_zone_center_y = size.y * (1.0 - hit_zone_position_percent)
	hit_zone_tolerance = size.y * hit_zone_size_percent * 0.5
	
	DebugLogger.log_message("Lane", "Lane %d - Size: %.1fx%.1f, Spawn: %.1f, Despawn: %.1f, HitZone: %.1f±%.1f" % 
		[lane_index, size.x, size.y, spawn_y, despawn_y, hit_zone_center_y, hit_zone_tolerance])
	
	# Update hit zone panel position if it exists
	if hit_zone_panel and size.y > 0:
		var hit_zone_y = hit_zone_center_y - (hit_zone_panel.size.y / 2.0)
		hit_zone_panel.position.y = hit_zone_y

func _process(delta):
	# Move all active notes down
	for i in range(active_notes.size() - 1, -1, -1):
		var note = active_notes[i]
		if not is_instance_valid(note):
			active_notes.remove_at(i)
			continue
		
		# Move note down
		note.position.y += note_speed * delta
		
		# Check if note has passed the despawn point (with some tolerance)
		var note_bottom = note.position.y + note.size.y
		if note_bottom >= despawn_y:
			_despawn_note(i, true)

func spawn_note():
	if not note_scene:
		DebugLogger.log_message("Lane", "No note scene assigned!")
		return
	
	var note = note_scene.instantiate()
	add_child(note)
	
	# Set note type based on lane
	if note.has_method("set_key_type"):
		note.set_key_type(lane_index)
	
	# Wait a frame for the note to get its size
	await get_tree().process_frame
	
	# Position at top center of lane
	note.position = Vector2(size.x / 2.0 - note.size.x / 2.0, spawn_y)
	active_notes.append(note)
	
	DebugLogger.log_message("Lane", "Spawned note for key %d at Y: %.1f" % [lane_index, spawn_y])

func check_hit():
	# Find the note closest to the hit zone
	var closest_note_index = -1
	var closest_distance = hit_zone_tolerance
	
	for i in range(active_notes.size()):
		var note = active_notes[i]
		var note_center_y = note.position.y + (note.size.y / 2.0)
		var distance = abs(note_center_y - hit_zone_center_y)
		
		if distance < closest_distance:
			closest_distance = distance
			closest_note_index = i
	
	if closest_note_index >= 0:
		# Hit successful
		_despawn_note(closest_note_index, false)
		note_hit.emit()
		DebugLogger.log_message("Lane", "Note hit!")
	else:
		DebugLogger.log_message("Lane", "No note in hit zone")

func set_note_speed(speed: float):
	note_speed = speed

func _despawn_note(index: int, missed: bool):
	if index < 0 or index >= active_notes.size():
		return
	
	var note = active_notes[index]
	active_notes.remove_at(index)
	note.queue_free()
	
	if missed:
		note_missed.emit()
		DebugLogger.log_message("Lane", "Note missed!")
		
func clear_notes():
	# Remove all active notes
	for note in active_notes:
		if is_instance_valid(note):
			note.queue_free()
	active_notes.clear()
	DebugLogger.log_message("Lane", "Cleared all notes from lane %d" % lane_index)
