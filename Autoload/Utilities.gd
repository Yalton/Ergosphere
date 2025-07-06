# CommonUtils.gd
extends Node

## Common utility functions to reduce code duplication

# Cached references for performance
static var _player_cache: Player = null

# Common state constants
const STATE_POWER = "power"
const STATE_EMERGENCY_MODE = "emergency_mode"
const STATE_LOCKDOWN = "lockdown"
const STATE_MAIN_DOOR_OPEN = "main_door_open"
const STATE_ENGINE_HEATSINK_OPERATIONAL = "engine_heatsink_operational"
const STATE_ALL_DAILY_TASKS_COMPLETE = "all_daily_tasks_complete"
const STATE_OXYGEN_SYSTEM_OPERATIONAL = "oxygen_system_operational"

# Timer creation helper - now static so it can be called from anywhere
func create_one_shot_timer(parent: Node, duration: float, callback: Callable) -> Timer:
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(callback)
	parent.add_child(timer)
	timer.start()
	return timer

# Safe node finding
func find_child_of_type(parent: Node, type: String) -> Node:
	for child in parent.get_children():
		if child.is_class(type):
			return child
	return null

# Find multiple children of type
func find_children_of_type(parent: Node, type: String) -> Array[Node]:
	var found: Array[Node] = []
	for child in parent.get_children():
		if child.is_class(type):
			found.append(child)
	return found

# Animation helper
func play_animation_safe(player: AnimationPlayer, anim_name: String) -> bool:
	if player and player.has_animation(anim_name):
		player.play(anim_name)
		return true
	return false

# State checking helper with constants
func check_game_state(state_name: String, expected_value = null) -> bool:
	if not GameManager or not GameManager.state_manager:
		return false
		
	var current = GameManager.state_manager.get_state(state_name)
	
	if expected_value == null:
		return current != null
	
	return current == expected_value

# Quick state checks using constants
func is_power_on() -> bool:
	return check_game_state(STATE_POWER, "on")

func is_emergency_mode() -> bool:
	return check_game_state(STATE_EMERGENCY_MODE, true)

func is_lockdown() -> bool:
	return check_game_state(STATE_LOCKDOWN, true)

# Task checking helper
func is_task_complete(task_id: String) -> bool:
	if not GameManager or not GameManager.task_manager:
		return false
		
	return GameManager.task_manager.is_task_completed(task_id)

# Player finding helper with caching
func get_player() -> Player:
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
func clear_player_cache() -> void:
	_player_cache = null

# Message sending helper
func send_player_message(text: String, speaker: String = "System") -> void:
	var player = get_player()
	if player and player.has_method("receive_message"):
		player.receive_message(speaker + ": " + text)

# Safe message sending with return value
func send_message_to_player_safe(message: String, speaker: String = "System") -> bool:
	var player = get_player()
	if player and player.has_method("receive_message"):
		player.receive_message(speaker + ": " + message)
		return true
	return false

# Send hint to player interaction component
func send_player_hint(title: String = "", text: String = "") -> bool:
	var player = get_player()
	if player and player.interaction_component:
		if player.interaction_component.has_method("send_hint"):
			player.interaction_component.send_hint(title, text)
			return true
	return false

# Safe signal connection
func connect_signal_safe(source: Object, signal_name: String, target: Object, method_name: String) -> bool:
	if not source or not target:
		return false
		
	if not source.has_signal(signal_name):
		return false
	
	var callable = Callable(target, method_name)
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)
		return true
		
	return false

# Safe node path finding
func safe_get_node(parent: Node, path: String) -> Node:
	if not parent:
		return null
	return parent.get_node_or_null(path)

# Safe method calling
func safe_call(object: Object, method: String, args: Array = []) -> Variant:
	if object and object.has_method(method):
		return object.callv(method, args)
	return null

# Create safe tween (kills existing if valid)
func create_safe_tween(node: Node, existing_tween: Tween = null) -> Tween:
	if existing_tween and existing_tween.is_valid():
		existing_tween.kill()
	return node.create_tween()

# Timer creation with optional auto-start
func create_timer(parent: Node, duration: float, one_shot: bool = true, auto_start: bool = true) -> Timer:
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = one_shot
	parent.add_child(timer)
	if auto_start:
		timer.start()
	return timer

# Get or create child node of type
func get_or_create_child(parent: Node, l_name: String, type: GDScript) -> Node:
	var child = parent.get_node_or_null(l_name)
	if not child:
		child = type.new()
		child.name = l_name
		parent.add_child(child)
	return child
