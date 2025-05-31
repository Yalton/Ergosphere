# WindowShuttersController.gd
extends Node3D

@export var enable_debug: bool = true
var module_name: String = "WindowShuttersController"

@export_group("Animation Settings")
@export var open_animation_name: String = "open"

# Internal state
var shutters_open: bool = false
var shutter_animation_players: Array[AnimationPlayer] = []

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Find all AnimationPlayer nodes in children
	_find_shutter_animation_players()
	
	DebugLogger.info(module_name, "Window shutters controller initialized with " + str(shutter_animation_players.size()) + " shutters")

func _find_shutter_animation_players() -> void:
	shutter_animation_players.clear()
	
	# Search through all children for AnimationPlayer nodes
	for child in get_children():
		var anim_player = _find_animation_player_recursive(child)
		if anim_player:
			shutter_animation_players.append(anim_player)
			DebugLogger.debug(module_name, "Found animation player in: " + child.name)

func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	# Check if this node is an AnimationPlayer
	if node is AnimationPlayer:
		return node as AnimationPlayer
	
	# Check children recursively
	for child in node.get_children():
		var result = _find_animation_player_recursive(child)
		if result:
			return result
	
	return null

# Called by the lever to open/close shutters
func set_shutters_state(open: bool) -> void:
	if shutters_open == open:
		DebugLogger.debug(module_name, "Shutters already in requested state: " + str(open))
		return
	
	shutters_open = open
	
	# Play animations on all shutters
	for anim_player in shutter_animation_players:
		if anim_player and anim_player.has_animation(open_animation_name):
			if open:
				# Play forward to open
				anim_player.play(open_animation_name)
			else:
				# Play in reverse to close
				anim_player.play_backwards(open_animation_name)
			
			DebugLogger.debug(module_name, "Playing " + open_animation_name + " " + ("forward" if open else "backwards") + " on " + anim_player.get_parent().name)
		else:
			DebugLogger.warning(module_name, "Animation player missing or animation '" + open_animation_name + "' not found")
	
	DebugLogger.info(module_name, "All shutters " + ("opening" if open else "closing"))

# Public method to check current state
func are_shutters_open() -> bool:
	return shutters_open
