extends Node
class_name LaneController

## Signal emitted when a note is successfully hit
signal note_hit(lane_index: int)

## Signal emitted when a note is missed
signal note_missed(lane_index: int)

## Array of lane nodes (should be 4 lanes for ASDF)
@export var lanes: Array[Node] = []

## Speed at which notes move down the lane (pixels per second)
@export var note_speed: float = 300.0

func _ready():
	DebugLogger.register_module("LaneController")
	
	# Connect to each lane's signals
	for i in range(lanes.size()):
		if lanes[i]:
			lanes[i].note_hit.connect(_on_lane_note_hit.bind(i))
			lanes[i].note_missed.connect(_on_lane_note_missed.bind(i))
			lanes[i].set_note_speed(note_speed)

func spawn_note(lane_index: int):
	if lane_index < 0 or lane_index >= lanes.size():
		DebugLogger.log_message("LaneController", "Invalid lane index: %d" % lane_index)
		return
	
	if lanes[lane_index]:
		lanes[lane_index].spawn_note()

func check_hit(lane_index: int):
	if lane_index < 0 or lane_index >= lanes.size():
		return
	
	if lanes[lane_index]:
		lanes[lane_index].check_hit()

func set_note_speed(speed: float):
	note_speed = speed
	for lane in lanes:
		if lane:
			lane.set_note_speed(speed)

func clear_all_notes():
	for lane in lanes:
		if lane and lane.has_method("clear_notes"):
			lane.clear_notes()

func _on_lane_note_hit(lane_index: int):
	note_hit.emit(lane_index)

func _on_lane_note_missed(lane_index: int):
	note_missed.emit(lane_index)
