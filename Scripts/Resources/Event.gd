# EventData.gd
extends Resource
class_name EventData

## Data structure for events with tension system support
## Includes category-specific cooldowns and relationship data

enum EventCategory {
	## Event was always going to occur at a scheduled time
	PLANNED,
	## Event triggered based on conditions/chance
	UNPLANNED,
	## Event can be both planned and triggered by conditions
	HYBRID
}

## Unique identifier for this event
@export var event_id: String = ""

## Human readable name for debugging
@export var event_name: String = ""

## Event category determines triggering behavior
@export var category: EventCategory = EventCategory.UNPLANNED

## Tension score (1-5) - how much psychological pressure this adds
@export_range(0, 5) var tension_score: int = 1

## Disruption score (1-5) - how much it disrupts player workflow
@export_range(0, 5) var disruption_score: int = 1

## Base chance percentage (0-100) for unplanned/hybrid events
@export_range(0.0, 100.0) var base_chance: float = 10.0

## Cooldown in seconds for tension level after this event triggers
@export var tension_cooldown: float = 30.0

## Cooldown in seconds for disruption level after this event triggers
@export var disruption_cooldown: float = 20.0

## Minimum day this event can occur (0 = any day)
@export var min_day: int = 0

## Maximum day this event can occur (0 = no limit)
@export var max_day: int = 0

## For planned events - which day it should occur
@export var scheduled_day: int = 0

## For planned events - what time of day (0-24 hours)
@export var scheduled_time_hours: float = 12.0

## Category-specific cooldowns and properties
@export_group("Category Settings")
## Whether this event has visual effects that need cooldown
@export var has_visual_effects: bool = false
## Visual effects cooldown override (0 = use tension_cooldown)
@export var visual_cooldown_override: float = 0.0
## Whether this event has audio that needs cooldown
@export var has_audio: bool = false
## Audio cooldown override (0 = use 70% of tension_cooldown)
@export var audio_cooldown_override: float = 0.0

## Event relationships - which events this boosts
@export_group("Event Relationships")
## Dictionary of event_id -> boost_multiplier for related events
@export var boosts_events: Dictionary = {}

## Custom data that can be used by event handlers
@export var custom_data: Dictionary = {}

func _init() -> void:
	# Generate default ID if not set
	if event_id.is_empty():
		event_id = "event_" + str(randi())
	
	# Update custom data with category flags
	_update_custom_data()

func _update_custom_data() -> void:
	## Sync category settings to custom data for backward compatibility
	if has_visual_effects:
		custom_data["has_visual"] = true
		if visual_cooldown_override > 0:
			custom_data["visual_cooldown"] = visual_cooldown_override
	
	if has_audio:
		custom_data["has_audio"] = true
		if audio_cooldown_override > 0:
			custom_data["audio_cooldown"] = audio_cooldown_override
	
	if not boosts_events.is_empty():
		custom_data["boosts_events"] = boosts_events

func is_valid() -> bool:
	## Check if this event data is properly configured
	if event_id.is_empty():
		return false
	
	if category == EventCategory.PLANNED and scheduled_day <= 0:
		return false
	
	if tension_score == 0 and disruption_score == 0:
		return false
	
	return true

func get_severity_description() -> String:
	## Get human readable severity description
	var max_score = max(tension_score, disruption_score)
	match max_score:
		1: return "Minor"
		2: return "Moderate"
		3: return "Significant" 
		4: return "Major"
		5: return "Critical"
		_: return "Unknown"

func get_category_description() -> String:
	## Get human readable category description
	match category:
		EventCategory.PLANNED: return "Planned"
		EventCategory.UNPLANNED: return "Unplanned"
		EventCategory.HYBRID: return "Hybrid"
		_: return "Unknown"

func get_tension_contribution() -> float:
	## Get how much tension this event would add
	var severity = max(tension_score, disruption_score)
	# This should match the event_tension_gain dictionary in EventManager
	match severity:
		1: return 5.0
		2: return 10.0
		3: return 20.0
		4: return 35.0
		5: return 50.0
		_: return 10.0
