# EventManager.gd
extends Node
class_name EventManager

## Main event system - handles all event types with global tension-based pacing
## Uses tension tracking to control event frequency and create breathing room

signal event_triggered(event_data: EventData)
signal event_completed(event_data: EventData)
signal tension_changed(new_tension: float)

var insanity_component: InsanityComponent = null
@export var enable_debug: bool = true
var module_name: String = "EventManager"

## Time between evaluation cycles in seconds
@export var evaluation_interval: float = 2.0

## Global tension value (0-100) - controls event frequency
@export var global_tension: float = 0.0

## How much tension decays per second
@export var tension_decay_rate: float = 2.0

## Tension decay multiplier for higher days (increases decay rate)
@export var day_tension_decay_multiplier: float = 0.3

## Base tension threshold - events need to roll under this minus global tension
@export var base_tension_threshold: float = 80.0

## How much tension increases when events trigger
@export var event_tension_gain: Dictionary = {
	1: 5.0,   # Minor events
	2: 10.0,  # Moderate events
	3: 20.0,  # Significant events
	4: 35.0,  # Major events
	5: 50.0   # Critical events
}

## Tension reduction when tasks are completed
@export var task_completion_tension_reduction: float = 15.0

## Event relationship boost duration in seconds
@export var relationship_boost_duration: float = 60.0

## Event configurations
@export var event_configurations: Array[EventData] = []

# Cooldown categories
var cooldown_categories: Dictionary = {
	"visual": {},    # Visual effects cooldowns
	"audio": {},     # Audio event cooldowns
	"gameplay": {}   # Gameplay disruption cooldowns
}

# Event relationships - which events boost chance of others
var event_relationships: Dictionary = {} # event_id -> {related_id: boost_multiplier}
var active_relationship_boosts: Array[RelationshipBoost] = []

# Current state
var scheduled_events: Array[ScheduledEvent] = []
var available_events: Array[EventData] = []
var current_day: int = 1
var insanity_level: float = 0.0
var grace_period_active: bool = false

# Event handlers
var event_handlers: Array[EventHandler] = []

# References
var state_manager: StateManager

# Evaluation timer
var evaluation_timer: Timer

class RelationshipBoost:
	var event_id: String
	var boost_multiplier: float
	var time_remaining: float

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Create evaluation timer
	evaluation_timer = Timer.new()
	evaluation_timer.wait_time = evaluation_interval
	evaluation_timer.timeout.connect(_evaluate_events)
	evaluation_timer.autostart = true
	add_child(evaluation_timer)
	
	DebugLogger.info(module_name, "EventManager initialized with tension system")

func _process(delta: float) -> void:
	# Update global tension
	_update_tension(delta)
	
	# Update cooldowns
	_update_cooldowns(delta)
	
	# Update relationship boosts
	_update_relationship_boosts(delta)

func _update_tension(delta: float) -> void:
	## Decay tension over time
	if global_tension > 0:
		var decay_rate = tension_decay_rate
		
		# Increase decay rate on higher days
		if current_day > 1:
			decay_rate += (current_day - 1) * day_tension_decay_multiplier
		
		var old_tension = global_tension
		global_tension = max(0, global_tension - (decay_rate * delta))
		
		if abs(old_tension - global_tension) > 0.1:
			tension_changed.emit(global_tension)

func _update_cooldowns(delta: float) -> void:
	## Update all cooldown categories
	for category in cooldown_categories:
		var cooldowns = cooldown_categories[category]
		var keys_to_remove = []
		
		for key in cooldowns:
			cooldowns[key] -= delta
			if cooldowns[key] <= 0:
				keys_to_remove.append(key)
		
		for key in keys_to_remove:
			cooldowns.erase(key)

func _update_relationship_boosts(delta: float) -> void:
	## Update active relationship boosts
	var expired_boosts = []
	
	for boost in active_relationship_boosts:
		boost.time_remaining -= delta
		if boost.time_remaining <= 0:
			expired_boosts.append(boost)
	
	for boost in expired_boosts:
		active_relationship_boosts.erase(boost)
		DebugLogger.debug(module_name, "Relationship boost expired for: %s" % boost.event_id)

func initialize(_state_manager: StateManager) -> void:
	## Initialize the event system
	state_manager = _state_manager
	
	available_events = event_configurations.duplicate()
	scheduled_events.clear()
	
	# Clear all cooldowns
	for category in cooldown_categories:
		cooldown_categories[category].clear()
	
	# Reset tension
	global_tension = 0.0
	
	# Connect signals
	event_triggered.connect(_on_event_triggered)
	event_completed.connect(_on_event_completed)
	
	# Find all event handlers
	_discover_event_handlers()
	
	# Schedule planned events
	for event in available_events:
		if event.category == EventData.EventCategory.PLANNED:
			_schedule_planned_event(event)
	
	# Connect to task completion if available
	if GameManager and GameManager.task_manager:
		if not GameManager.task_manager.task_completed.is_connected(_on_task_completed):
			GameManager.task_manager.task_completed.connect(_on_task_completed)
	
	# Setup event relationships
	_setup_event_relationships()
	
	DebugLogger.info(module_name, "Initialized with tension system")

func _can_event_trigger(event: EventData) -> bool:
	## Check if event meets prerequisites and cooldown requirements
	
	# Check prerequisites
	if not _check_prerequisites(event):
		return false
	
	# Check if we're in grace period
	if grace_period_active:
		return false
	
	# Check cooldowns based on event type
	if not _check_event_cooldowns(event):
		return false
	
	return true

func _check_event_cooldowns(event: EventData) -> bool:
	## Check category-specific cooldowns
	var event_categories = _get_event_categories(event)
	
	for category in event_categories:
		var cooldown_key = _get_cooldown_key_for_category(event, category)
		if cooldown_categories[category].has(cooldown_key):
			return false
	
	return true

func _get_event_categories(event: EventData) -> Array:
	## Determine which cooldown categories this event belongs to
	var categories = []
	
	# Check custom data for category hints
	if event.custom_data.has("has_visual"):
		categories.append("visual")
	if event.custom_data.has("has_audio"):
		categories.append("audio")
	if event.disruption_score > 0:
		categories.append("gameplay")
	
	# Default to gameplay if no categories specified
	if categories.is_empty():
		categories.append("gameplay")
	
	return categories

func _get_cooldown_key_for_category(event: EventData, category: String) -> String:
	## Generate cooldown key based on category and severity
	match category:
		"visual":
			return "visual_%d" % event.tension_score
		"audio":
			return "audio_%d" % event.tension_score
		"gameplay":
			return "gameplay_%d" % event.disruption_score
		_:
			return "%s_%d" % [category, max(event.tension_score, event.disruption_score)]

func _should_event_trigger(event: EventData) -> bool:
	## Calculate if event should trigger based on tension system
	
	# Get base chance modified by insanity
	var base_chance = event.base_chance
	var modified_chance = _calculate_modified_chance(base_chance, event)
	
	# Apply tension gating - higher tension = lower chance
	var tension_gate = base_tension_threshold - global_tension
	modified_chance = modified_chance * (tension_gate / 100.0)
	
	# Roll for trigger
	var roll = randf() * 100.0
	var triggered = roll <= modified_chance
	
	DebugLogger.debug(module_name, 
		"Event %s: base=%.1f%%, modified=%.1f%%, tension_gate=%.1f%%, roll=%.1f%%, trigger=%s" % 
		[event.event_id, base_chance, modified_chance, tension_gate, roll, str(triggered)])
	
	return triggered

func _calculate_modified_chance(base_chance: float, event: EventData) -> float:
	## Apply all modifiers to base chance
	var modified_chance = base_chance
	
	# Get insanity from component
	var current_insanity = insanity_component.current_insanity if insanity_component else insanity_level
	
	# Insanity modifier (increases chance, overcomes tension)
	var insanity_modifier = 1.0 + (current_insanity / 50.0) # 200% boost at max insanity
	modified_chance *= insanity_modifier
	
	# Day progression modifier
	var day_modifier = 1.0 + ((current_day - 1) * 0.15)
	modified_chance *= day_modifier
	
	# Check for relationship boosts
	var relationship_modifier = _get_relationship_boost(event.event_id)
	modified_chance *= relationship_modifier
	
	# Clamp to reasonable bounds
	modified_chance = clamp(modified_chance, 0.0, 95.0)
	
	return modified_chance

func _get_relationship_boost(event_id: String) -> float:
	## Get multiplier from active relationship boosts
	var boost_multiplier = 1.0
	
	for boost in active_relationship_boosts:
		if boost.event_id == event_id:
			boost_multiplier = max(boost_multiplier, boost.boost_multiplier)
	
	return boost_multiplier

func _trigger_event(event: EventData) -> void:
	## Trigger event and update tension/cooldowns
	
	# Increase global tension
	var severity = max(event.tension_score, event.disruption_score)
	var tension_gain = event_tension_gain.get(severity, 10.0)
	global_tension = min(100.0, global_tension + tension_gain)
	tension_changed.emit(global_tension)
	
	# Apply category-specific cooldowns
	_start_category_cooldowns(event)
	
	# Apply relationship boosts
	_apply_relationship_boosts(event)
	
	# Emit signal
	event_triggered.emit(event)
	
	DebugLogger.info(module_name, 
		"Triggered event: %s (T:%d D:%d) - Tension: %.1f (+%.1f)" % 
		[event.event_id, event.tension_score, event.disruption_score, global_tension, tension_gain])

func _start_category_cooldowns(event: EventData) -> void:
	## Start cooldowns for each category this event belongs to
	var categories = _get_event_categories(event)
	
	for category in categories:
		var cooldown_key = _get_cooldown_key_for_category(event, category)
		var cooldown_time = _get_cooldown_time_for_category(event, category)
		
		# Apply insanity modifier to cooldown
		if insanity_component:
			cooldown_time *= insanity_component.get_event_cooldown_multiplier()
		
		cooldown_categories[category][cooldown_key] = cooldown_time
		DebugLogger.debug(module_name, "Started %s cooldown: %s = %.1fs" % [category, cooldown_key, cooldown_time])

func _get_cooldown_time_for_category(event: EventData, category: String) -> float:
	## Get appropriate cooldown time for category
	match category:
		"visual":
			return event.custom_data.get("visual_cooldown", event.tension_cooldown)
		"audio":
			return event.custom_data.get("audio_cooldown", event.tension_cooldown * 0.7)
		"gameplay":
			return event.disruption_cooldown
		_:
			return max(event.tension_cooldown, event.disruption_cooldown)

func _apply_relationship_boosts(event: EventData) -> void:
	## Apply temporary boosts to related events
	if not event_relationships.has(event.event_id):
		return
	
	var relationships = event_relationships[event.event_id]
	for related_id in relationships:
		var boost = RelationshipBoost.new()
		boost.event_id = related_id
		boost.boost_multiplier = relationships[related_id]
		boost.time_remaining = relationship_boost_duration
		
		active_relationship_boosts.append(boost)
		DebugLogger.debug(module_name, 
			"Added relationship boost: %s -> %s (x%.1f for %.1fs)" % 
			[event.event_id, related_id, boost.boost_multiplier, relationship_boost_duration])

func _setup_event_relationships() -> void:
	## Setup which events boost the chance of other events
	# This should be configured based on your game's event design
	# Example:
	# event_relationships["lights_flicker"] = {"power_outage": 2.0, "darkness_event": 1.5}
	# event_relationships["strange_noise"] = {"creature_appears": 1.8, "door_slam": 1.3}
	
	# Load from event custom data if available
	for event in available_events:
		if event.custom_data.has("boosts_events"):
			event_relationships[event.event_id] = event.custom_data["boosts_events"]

func _on_task_completed(_task_id: String) -> void:
	## Reduce tension when tasks are completed
	var old_tension = global_tension
	global_tension = max(0, global_tension - task_completion_tension_reduction)
	
	if old_tension != global_tension:
		tension_changed.emit(global_tension)
		DebugLogger.debug(module_name, 
			"Task completed - Tension reduced: %.1f -> %.1f" % 
			[old_tension, global_tension])

func start_new_day(day_number: int) -> void:
	## Handle day transition
	DebugLogger.info(module_name, "Starting new day: %d" % day_number)
	
	# Update current day
	current_day = day_number
	
	# Get insanity component
	_check_for_insanity_component()
	
	# Reset tension to reasonable starting value
	global_tension = 20.0 + (day_number * 5.0) # Start with some tension that increases per day
	tension_changed.emit(global_tension)
	
	# Clear all cooldowns for fresh start
	for category in cooldown_categories:
		cooldown_categories[category].clear()
	
	# Start grace period
	_start_grace_period()
	
	DebugLogger.info(module_name, "Day %d started - Tension: %.1f, Grace period: 30s" % [day_number, global_tension])

func _start_grace_period() -> void:
	## Start grace period where no events can trigger
	grace_period_active = true
	evaluation_timer.stop()
	
	var grace_timer = Timer.new()
	grace_timer.wait_time = 30.0
	grace_timer.one_shot = true
	grace_timer.timeout.connect(_end_grace_period)
	add_child(grace_timer)
	grace_timer.start()
	
	DebugLogger.debug(module_name, "Grace period started - events disabled for 30s")

func _end_grace_period() -> void:
	## End grace period and resume event evaluation
	grace_period_active = false
	evaluation_timer.start()
	DebugLogger.debug(module_name, "Grace period ended - events enabled")

# Keep existing helper functions
func _check_for_insanity_component() -> void:
	var player = CommonUtils.get_player()
	if player:
		insanity_component = player.get_node("InsanityComponent")
		if insanity_component:
			DebugLogger.debug(module_name, "InsanityComponent found")

func _discover_event_handlers() -> void:
	event_handlers.clear()
	var nodes = get_tree().get_nodes_in_group("event_handlers")
	for node in nodes:
		if node is EventHandler:
			event_handlers.append(node)
	DebugLogger.debug(module_name, "Found %d event handlers" % event_handlers.size())

func _check_prerequisites(event: EventData) -> bool:
	if event.min_day > 0 and current_day < event.min_day:
		return false
	if event.max_day > 0 and current_day > event.max_day:
		return false
	return true

func _schedule_planned_event(event: EventData) -> void:
	if event.scheduled_day <= 0:
		return
		
	var scheduled = ScheduledEvent.new()
	scheduled.event_id = event.event_id
	scheduled.scheduled_day = event.scheduled_day
	
	var day_start_time = Time.get_unix_time_from_system()
	var hours_in_seconds = event.scheduled_time_hours * 3600
	scheduled.trigger_time = day_start_time + hours_in_seconds
	
	scheduled_events.append(scheduled)
	DebugLogger.debug(module_name, "Scheduled event %s for day %d at %.1f hours" % 
		[event.event_id, event.scheduled_day, event.scheduled_time_hours])

func _check_scheduled_events() -> void:
	var current_time = Time.get_unix_time_from_system()
	var events_to_remove: Array[ScheduledEvent] = []
	
	for scheduled in scheduled_events:
		if current_time >= scheduled.trigger_time and current_day == scheduled.scheduled_day:
			force_trigger_event(scheduled.event_id)
			events_to_remove.append(scheduled)
	
	for event in events_to_remove:
		scheduled_events.erase(event)

func _evaluate_events() -> void:
	if available_events.is_empty() or grace_period_active:
		return
	
	_check_scheduled_events()
	
	for event in available_events:
		if event.category == EventData.EventCategory.PLANNED:
			continue
			
		if _can_event_trigger(event) and _should_event_trigger(event):
			_trigger_event(event)
			break

func _find_event_by_id(event_id: String) -> EventData:
	for event in available_events:
		if event.event_id == event_id:
			return event
	return null

func _on_event_triggered(event_data: EventData) -> void:
	for handler in event_handlers:
		if handler.has_method("handle_event"):
			handler.handle_event(event_data)

func _on_event_completed(event_data: EventData) -> void:
	DebugLogger.debug(module_name, "Event completed: %s" % event_data.event_id)

func force_trigger_event(event_id: String) -> void:
	var event = _find_event_by_id(event_id)
	if not event:
		DebugLogger.error(module_name, "Cannot force trigger - event not found: %s" % event_id)
		return
	
	_trigger_event(event)
	DebugLogger.info(module_name, "Force triggered event: %s" % event_id)

func complete_event(event_id: String) -> void:
	var event_data = _find_event_by_id(event_id)
	if event_data:
		event_completed.emit(event_data)
	else:
		DebugLogger.error(module_name, "Cannot complete unknown event: %s" % event_id)

# Dev console support
func get_tension_info() -> Dictionary:
	return {
		"global_tension": global_tension,
		"tension_decay_rate": tension_decay_rate * (1 + (current_day - 1) * day_tension_decay_multiplier),
		"grace_period_active": grace_period_active,
		"active_boosts": active_relationship_boosts.size(),
		"cooldowns": {
			"visual": cooldown_categories["visual"].size(),
			"audio": cooldown_categories["audio"].size(),
			"gameplay": cooldown_categories["gameplay"].size()
		}
	}

class ScheduledEvent:
	var event_id: String
	var scheduled_day: int
	var trigger_time: float
