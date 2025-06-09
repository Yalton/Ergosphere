# CommonUtils.gd
extends Node

## Common utility functions to reduce code duplication

# Cached references for performance
static var _player_cache: Player = null
static var _cache_timer: float = 0.0

# Common state constants
const STATE_POWER = "power"
const STATE_EMERGENCY_MODE = "emergency_mode"
const STATE_LOCKDOWN = "lockdown"
const STATE_MAIN_DOOR_OPEN = "main_door_open"
const STATE_ENGINE_HEATSINK_OPERATIONAL = "engine_heatsink_operational"
const STATE_ALL_DAILY_TASKS_COMPLETE = "all_daily_tasks_complete"
const STATE_OXYGEN_SYSTEM_OPERATIONAL = "oxygen_system_operational"

# Timer creation helper
static func create_one_shot_timer(parent: Node, duration: float, callback: Callable) -> Timer:
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(callback)
	parent.add_child(timer)
	timer.start()
	return timer

# Safe node finding
static func find_child_of_type(parent: Node, type: String) -> Node:
	for child in parent.get_children():
		if child.is_class(type):
			return child
	return null

# Find multiple children of type
static func find_children_of_type(parent: Node, type: String) -> Array[Node]:
	var found: Array[Node] = []
	for child in parent.get_children():
		if child.is_class(type):
			found.append(child)
	return found

# Animation helper
static func play_animation_safe(player: AnimationPlayer, anim_name: String) -> bool:
	if player and player.has_animation(anim_name):
		player.play(anim_name)
		return true
	return false

# State checking helper with constants
static func check_game_state(state_name: String, expected_value = null) -> bool:
	if not GameManager or not GameManager.state_manager:
		return false
		
	var current = GameManager.state_manager.get_state(state_name)
	
	if expected_value == null:
		return current != null
	
	return current == expected_value

# Quick state checks using constants
static func is_power_on() -> bool:
	return check_game_state(STATE_POWER, "on")

static func is_emergency_mode() -> bool:
	return check_game_state(STATE_EMERGENCY_MODE, true)

static func is_lockdown() -> bool:
	return check_game_state(STATE_LOCKDOWN, true)

# Task checking helper
static func is_task_complete(task_id: String) -> bool:
	if not GameManager or not GameManager.task_manager:
		return false
		
	return GameManager.task_manager.is_task_completed(task_id)

# Player finding helper with caching
static func get_player() -> Player:
	# Return cached player if valid
	if _player_cache and is_instance_valid(_player_cache):
		return _player_cache
	
	# Find and cache player
	var players = Engine.get_main_loop().get_nodes_in_group("player")
	if players.size() > 0:
		_player_cache = players[0]
		return _player_cache
	return null

# Clear player cache (call when player changes/respawns)
static func clear_player_cache() -> void:
	_player_cache = null

# Message sending helper
static func send_player_message(text: String, speaker: String = "System") -> void:
	var player = get_player()
	if player and player.has_method("receive_message"):
		player.receive_message(speaker + ": " + text)

# Safe message sending with return value
static func send_message_to_player_safe(message: String, speaker: String = "System") -> bool:
	var player = get_player()
	if player and player.has_method("receive_message"):
		player.receive_message(speaker + ": " + message)
		return true
	return false

# Send hint to player interaction component
static func send_player_hint(title: String = "", text: String = "") -> bool:
	var player = get_player()
	if player and player.has_property("interaction_component") and player.interaction_component:
		if player.interaction_component.has_method("send_hint"):
			player.interaction_component.send_hint(title, text)
			return true
	return false

# Safe signal connection
static func connect_signal_safe(source: Object, signal_name: String, target: Object, method: String) -> bool:
	if not source or not is_instance_valid(source):
		return false
		
	if not source.has_signal(signal_name):
		return false
		
	var callable = Callable(target, method)
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)
		return true
		
	return false

# Disconnect signal safely
static func disconnect_signal_safe(source: Object, signal_name: String, target: Object, method: String) -> bool:
	if not source or not is_instance_valid(source):
		return false
		
	if not source.has_signal(signal_name):
		return false
		
	var callable = Callable(target, method)
	if source.is_connected(signal_name, callable):
		source.disconnect(signal_name, callable)
		return true
		
	return false

# Get nodes in group with caching consideration
static func get_nodes_in_group_cached(group: String, force_refresh: bool = false) -> Array:
	# For now, just wrap the call - could add caching layer later
	return Engine.get_main_loop().get_nodes_in_group(group)

# Find first node in group
static func get_first_node_in_group(group: String) -> Node:
	var nodes = Engine.get_main_loop().get_nodes_in_group(group)
	return nodes[0] if nodes.size() > 0 else null

# Generic transition helper (if TransitionManager is available)
static func transition_scene(hide_func: Callable, prepare_func: Callable, show_func: Callable, delay: float = 0.1) -> void:
	if not TransitionManager:
		# Fallback without transition
		hide_func.call()
		prepare_func.call()
		show_func.call()
		return
		
	# Use transition manager
	await TransitionManager.fade_to_black()
	hide_func.call()
	prepare_func.call()
	await Engine.get_main_loop().create_timer(delay).timeout
	show_func.call()
	await TransitionManager.fade_from_black()

# Audio helper using Audio singleton
static func play_audio(sound: AudioStream, pitch: float = 1.0, volume: float = 0.0, bus: String = "Master") -> AudioStreamPlayer:
	if Audio:
		return Audio.play_sound(sound, true, pitch, volume, bus)
	return null

# Play audio with random pitch
static func play_audio_varied(sound: AudioStream, min_pitch: float = 0.9, max_pitch: float = 1.1, volume: float = 0.0, bus: String = "Master") -> AudioStreamPlayer:
	if Audio:
		var pitch = randf_range(min_pitch, max_pitch)
		return Audio.play_sound(sound, true, pitch, volume, bus)
	return null

# Check if node has property
static func has_property(object: Object, property: String) -> bool:
	return property in object

# Safe property getter
static func get_property_safe(object: Object, property: String, default_value = null):
	if object and property in object:
		return object.get(property)
	return default_value

# Create a dictionary from arrays (useful for lookups)
static func create_lookup_dict(keys: Array, values: Array) -> Dictionary:
	var dict = {}
	var count = min(keys.size(), values.size())
	for i in range(count):
		dict[keys[i]] = values[i]
	return dict

# Batch operations on nodes in group
static func call_on_group(group: String, method: String, args: Array = []) -> void:
	var nodes = Engine.get_main_loop().get_nodes_in_group(group)
	for node in nodes:
		if node.has_method(method):
			node.callv(method, args)

# Safe scene change with transition
static func change_scene_safe(scene_path: String) -> void:
	if TransitionManager:
		await TransitionManager.transition_to_scene(scene_path)
	else:
		Engine.get_main_loop().change_scene_to_file(scene_path)
