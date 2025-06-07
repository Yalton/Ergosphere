# CommonUtils.gd
extends Node


## Common utility functions to reduce code duplication

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

# Animation helper
static func play_animation_safe(player: AnimationPlayer, anim_name: String) -> bool:
	if player and player.has_animation(anim_name):
		player.play(anim_name)
		return true
	return false

# State checking helper  
static func check_game_state(state_name: String, expected_value = null) -> bool:
	if not GameManager or not GameManager.state_manager:
		return false
		
	var current = GameManager.state_manager.get_state(state_name)
	
	if expected_value == null:
		return current != null
	
	return current == expected_value

# Task checking helper
static func is_task_complete(task_id: String) -> bool:
	if not GameManager or not GameManager.task_manager:
		return false
		
	return GameManager.task_manager.is_task_completed(task_id)

# Player finding helper
static func get_player() -> Player:
	var players = Engine.get_main_loop().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

# Message sending helper
static func send_player_message(text: String, speaker: String = "System") -> void:
	var player = get_player()
	if player and player.has_method("receive_message"):
		player.receive_message(speaker + ": " + text)

# Safe signal connection
static func connect_signal_safe(source: Object, signal_name: String, target: Object, method: String) -> bool:
	if not source.has_signal(signal_name):
		return false
		
	if not source.is_connected(signal_name, Callable(target, method)):
		source.connect(signal_name, Callable(target, method))
		return true
		
	return false
