
extends DiegeticUIBase
class_name GlobeUI

signal mission_selected_signal(continent: Continent, map: Map, mission: Mission)
signal items_purchased_signal(items: Array[InventoryItemPD])

@export var globe: Node3D
@export var ui_component : Control 
@export var earth_cam : Camera3D
@export var earth_node : Node3D

@export var lira_amount: int = 100
@export var faith_amount: int = 80

var is_dragging: bool = false
var current_rotation: Vector3 = Vector3.ZERO
var current_rotation_quat: Quaternion = Quaternion.IDENTITY

func _ready() -> void:
	super._ready()
	usable_interaction_text = "Use Globe"
	unusable_interaction_text = "Globe Locked"
	ui_component.continent_selected_signal.connect(_on_continent_selected)
	ui_component.mission_selected_signal.connect(_on_mission_selected_signal)
	ui_component.items_purchased_signal.connect(_on_items_purchased_signal)
	current_rotation_quat = Quaternion.from_euler(globe.rotation)
	globe.rotation = Vector3.ZERO

func _input(event: InputEvent) -> void:
	super._input(event)
	
	#if event is InputEventMouseButton:
		#is_dragging = event.pressed and event.button_index == MOUSE_BUTTON_LEFT

func handle_interaction(local_point: Vector3) -> void:
	super.handle_interaction(local_point)
	
	#if is_dragging:
		#_rotate_globe(last_interaction_point - Vector2(sub_viewport.size) / 2)

func reset_globe_rotation() -> void:
	globe.rotation = Vector3.ZERO
	print("Globe rotation reset")

func rotate_globe(target_rotation: Vector3) -> void:
	var rotation_tween = create_tween()
	var camera_tween = create_tween()
	
	# Camera zoom effect
	var mid_fov = 75
	var end_fov = 65
	
	camera_tween.tween_property(earth_cam, "fov", mid_fov, 0.5).set_trans(Tween.TRANS_CUBIC)
	camera_tween.tween_interval(0.1)
	camera_tween.tween_property(earth_cam, "fov", end_fov, 0.5).set_trans(Tween.TRANS_CUBIC)
	
	# Convert target rotation to quaternion
	var target_quat = Quaternion.from_euler(target_rotation * PI / 180.0)
	
	# Find the shortest path between current and target rotations
	var shortest_rotation = current_rotation_quat.slerp(target_quat, 1.0)
	
	# Rotate the globe
	var duration = 1.0 if target_rotation != Vector3.ZERO else 0.5
	rotation_tween.tween_method(set_globe_rotation, current_rotation_quat, shortest_rotation, duration).set_trans(Tween.TRANS_CUBIC)
	
	current_rotation_quat = shortest_rotation
	print("Target Globe Rotation ", target_rotation)

func set_globe_rotation(quat: Quaternion) -> void:
	globe.transform.basis = Basis(quat)

func _on_continent_selected(continent : Continent)-> void:
	if continent: 
		match continent.Name:
			"Asia": 
				rotate_globe(Vector3(-32, 180, 0))
			"Africa": 
				rotate_globe(Vector3(0, -110, 0 ))
			"North America": 
				rotate_globe(Vector3(32, 10, 8))
			"South America": 
				rotate_globe(Vector3(-8, -35, 18))
			"Antarctica": 
				rotate_globe(Vector3(0, -92, 88))
			"Europe": 
				rotate_globe(Vector3(0, -100, -46))
			"Oceania":
				rotate_globe(Vector3(12, 150, 0 ))
	else: 
		rotate_globe(Vector3(0, 0, 0))

func _on_mission_selected_signal(continent: Continent, map: Map, mission: Mission) -> void: 
	mission_selected_signal.emit(continent, map, mission)

func _on_items_purchased_signal(items: Array[InventoryItemPD]): 
	items_purchased_signal.emit(items)


#func rotate_globe(passed_rotation: Vector3) -> void:
	#var rotation_tween = create_tween()
	#var camera_tween = create_tween()
	#
	## Start with current FOV
	#var start_fov = earth_cam.fov
	#var mid_fov = 75  # Zoom out to this FOV
	#var end_fov = 65  # Final zoomed-in FOV
	#
	## Zoom out
	#camera_tween.tween_property(earth_cam, "fov", mid_fov, 0.5).set_trans(Tween.TRANS_CUBIC)
	#
	## Zoom in after a slight delay
	#camera_tween.tween_interval(0.1)  # Small pause at maximum zoom out
	#camera_tween.tween_property(earth_cam, "fov", end_fov, 0.5).set_trans(Tween.TRANS_CUBIC)
	#
	## Rotate the globe
	#if passed_rotation != Vector3.ZERO:
		#rotation_tween.tween_property(globe, "rotation_degrees", passed_rotation, 1.0).set_trans(Tween.TRANS_CUBIC)
	#else:
		## If resetting to zero, maybe a faster rotation
		#rotation_tween.tween_property(globe, "rotation_degrees", passed_rotation, 0.5).set_trans(Tween.TRANS_CUBIC)
	#
	#print("Target Globe Rotation ", passed_rotation)

func reset_ui(): 
	ui_component.lira_amount = lira_amount
	ui_component.faith_amount = faith_amount
	ui_component.reset()
