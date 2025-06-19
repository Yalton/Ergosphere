# BlackHole.gd
extends Node3D
class_name BlackHole

## Time in seconds the player has been looking at the black hole
@export var view_time: float = 0.0

## How long the player has been looking at it in the current session
@export var current_view_time: float = 0.0

## Whether the black hole is currently visible on screen
@export var is_visible: bool = false

var module_name: String = "BlackHole"

@onready var visible_notifier: VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D

func _ready() -> void:
	# Register with DebugLogger
	DebugLogger.register_module(module_name, true)
	
	# Connect visibility signals
	if visible_notifier:
		visible_notifier.screen_entered.connect(_on_screen_entered)
		visible_notifier.screen_exited.connect(_on_screen_exited)
		DebugLogger.debug(module_name, "Visibility notifier connected")
	else:
		DebugLogger.error(module_name, "VisibleOnScreenNotifier3D not found as child")

func _process(delta: float) -> void:
	if is_visible:
		current_view_time += delta
		view_time += delta
		
		# Debug log every 5 seconds
		if int(current_view_time) % 5 == 0 and int(current_view_time) != int(current_view_time - delta):
			DebugLogger.debug(module_name, "Player looking at black hole for: " + str(current_view_time) + "s")

func _on_screen_entered() -> void:
	is_visible = true
	DebugLogger.debug(module_name, "Black hole entered screen")

func _on_screen_exited() -> void:
	is_visible = false
	DebugLogger.debug(module_name, "Black hole exited screen - was visible for: " + str(current_view_time) + "s")
	current_view_time = 0.0

func get_total_view_time() -> float:
	return view_time

func get_current_view_time() -> float:
	return current_view_time

func reset_view_time() -> void:
	view_time = 0.0
	current_view_time = 0.0
	DebugLogger.debug(module_name, "View time reset")
