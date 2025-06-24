# MessageBus.gd
extends Node

## Simple message bus for decoupled communication between systems
## Add as autoload: MessageBus

@export var enable_debug: bool = true
var module_name: String = "MessageBus"

# Message history for debugging
var message_history: Array = []
var max_history: int = 100

# Subscriber tracking for debugging
var _subscribers: Dictionary = {} # message_type -> Array of subscribers

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	DebugLogger.info(module_name, "MessageBus initialized")

#region Core Messaging

## Send a message to all subscribers
func send(message_type: String, data: Dictionary = {}) -> void:
	# Add timestamp and type to data
	data["_timestamp"] = Time.get_ticks_msec()
	data["_type"] = message_type
	
	# Add to history
	_add_to_history(message_type, data)
	
	# Log if debug enabled
	if enable_debug:
		DebugLogger.debug(module_name, "Message sent: %s with data: %s" % [message_type, data])
	
	# Get all subscribers for this message type
	var subscribers = _get_subscribers(message_type)
	
	# Also get wildcard subscribers
	var wildcard_subscribers = _get_subscribers("*")
	
	# Call all subscribers
	for subscriber in subscribers:
		if is_instance_valid(subscriber.target):
			subscriber.callback.call(data)
		else:
			# Clean up invalid subscriber
			_remove_invalid_subscriber(message_type, subscriber)
	
	# Call wildcard subscribers with message type
	for subscriber in wildcard_subscribers:
		if is_instance_valid(subscriber.target):
			subscriber.callback.call(message_type, data)
		else:
			_remove_invalid_subscriber("*", subscriber)

## Subscribe to a specific message type
func subscribe(message_type: String, target: Object, method: String) -> void:
	if not target or not target.has_method(method):
		DebugLogger.error(module_name, "Invalid subscription target or method: %s.%s" % [target, method])
		return
	
	var callback = Callable(target, method)
	var subscriber = {
		"target": target,
		"callback": callback,
		"method_name": method
	}
	
	if not _subscribers.has(message_type):
		_subscribers[message_type] = []
	
	# Check for duplicates
	for existing in _subscribers[message_type]:
		if existing.target == target and existing.method_name == method:
			DebugLogger.warning(module_name, "Duplicate subscription ignored: %s.%s for %s" % [target, method, message_type])
			return
	
	_subscribers[message_type].append(subscriber)
	DebugLogger.debug(module_name, "Subscribed: %s.%s to %s" % [target.get_class(), method, message_type])

## Unsubscribe from a specific message type
func unsubscribe(message_type: String, target: Object, method: String = "") -> void:
	if not _subscribers.has(message_type):
		return
	
	var subscribers = _subscribers[message_type]
	for i in range(subscribers.size() - 1, -1, -1):
		var sub = subscribers[i]
		if sub.target == target and (method.is_empty() or sub.method_name == method):
			subscribers.remove_at(i)
			DebugLogger.debug(module_name, "Unsubscribed: %s from %s" % [target.get_class(), message_type])

## Unsubscribe from all message types
func unsubscribe_all(target: Object) -> void:
	for message_type in _subscribers:
		unsubscribe(message_type, target)

#endregion

#region Convenience Methods

## Send a task-related message
func send_task(task_event: String, task_id: String, extra_data: Dictionary = {}) -> void:
	var data = {
		"task_id": task_id,
		"event": task_event
	}
	data.merge(extra_data)
	send("task." + task_event, data)

## Send a state change message
func send_state(state_name: String, new_value, old_value = null) -> void:
	send("state.changed", {
		"state": state_name,
		"value": new_value,
		"old_value": old_value
	})

## Send an interaction message
func send_interaction(interaction_type: String, object_name: String, extra_data: Dictionary = {}) -> void:
	var data = {
		"object": object_name,
		"interaction": interaction_type
	}
	data.merge(extra_data)
	send("interaction." + interaction_type, data)

## Send a system event
func send_system(event_name: String, extra_data: Dictionary = {}) -> void:
	send("system." + event_name, extra_data)

#endregion

#region Debug and Utility

## Get message history for debugging
func get_history(message_type: String = "") -> Array:
	if message_type.is_empty():
		return message_history
	
	return message_history.filter(func(msg): return msg.type == message_type)

## Clear message history
func clear_history() -> void:
	message_history.clear()
	DebugLogger.debug(module_name, "Message history cleared")

## Get subscriber count for a message type
func get_subscriber_count(message_type: String) -> int:
	if not _subscribers.has(message_type):
		return 0
	
	# Clean up invalid subscribers first
	var valid_count = 0
	var subscribers = _subscribers[message_type]
	for sub in subscribers:
		if is_instance_valid(sub.target):
			valid_count += 1
	
	return valid_count

## Debug print all subscribers
func debug_print_subscribers() -> void:
	print("\n=== MessageBus Subscribers ===")
	for message_type in _subscribers:
		var count = get_subscriber_count(message_type)
		if count > 0:
			print("%s: %d subscribers" % [message_type, count])
			for sub in _subscribers[message_type]:
				if is_instance_valid(sub.target):
					print("  - %s.%s" % [sub.target.get_class(), sub.method_name])
	print("==============================\n")

#endregion

#region Internal Helpers

func _get_subscribers(message_type: String) -> Array:
	if not _subscribers.has(message_type):
		return []
	return _subscribers[message_type]

func _add_to_history(message_type: String, data: Dictionary) -> void:
	var entry = {
		"type": message_type,
		"data": data,
		"time": Time.get_ticks_msec()
	}
	
	message_history.append(entry)
	
	# Limit history size
	if message_history.size() > max_history:
		message_history.pop_front()

func _remove_invalid_subscriber(message_type: String, subscriber: Dictionary) -> void:
	if _subscribers.has(message_type):
		_subscribers[message_type].erase(subscriber)

#endregion

#region Common Message Types
# Define common message types as constants for consistency

# Task messages
const TASK_ASSIGNED = "task.assigned"
const TASK_COMPLETED = "task.completed"
const TASK_FAILED = "task.failed"
const TASK_AVAILABLE = "task.available"
const TASK_UNAVAILABLE = "task.unavailable"

# State messages
const STATE_CHANGED = "state.changed"
const POWER_CHANGED = "state.power"
const EMERGENCY_MODE = "state.emergency"
const LOCKDOWN_CHANGED = "state.lockdown"

# Interaction messages
const INTERACT_STARTED = "interaction.started"
const INTERACT_ENDED = "interaction.ended"
const OBJECT_USED = "interaction.used"

# System messages
const DAY_STARTED = "system.day_started"
const DAY_ENDED = "system.day_ended"
const GAME_PAUSED = "system.paused"
const GAME_RESUMED = "system.resumed"

# Event messages
const EVENT_TRIGGERED = "event.triggered"
const EVENT_COMPLETED = "event.completed"
const EVENT_FAILED = "event.failed"

#endregion
