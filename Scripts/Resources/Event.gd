# Event.gd
extends Resource
class_name EventData

## Unique identifier for this event
@export var id: String = ""

## Display name for debugging/UI
@export var name: String = "Unnamed Event"

## Detailed description of what this event does
@export var description: String = ""

@export_group("Cost and Balance")
## Point cost to trigger this event
@export var cost: int = 10

## How disruptive this event is (0-100). Multiple events cannot exceed 100% total disruption
@export var disruption_percentage: int = 20

## Minimum day this event can occur on (1-5)
@export_range(1, 5) var min_day: int = 1

## Cooldown in seconds after this event ends before it can trigger again
@export var cooldown: float = 60.0

@export_group("Categorization")
## Tags for this event (e.g. ["scary", "power", "disruptive", "story"])
@export var tags: Array[String] = []

## Type of event for preventing conflicts
@export_enum("NONE", "STORY_MOMENT", "STATION_EMERGENCY", "SPOOKY_BRIEF", "SPOOKY_ENDURING", "MISC_DISRUPTIVE") var event_type: String = "NONE"

## Check if this event has a specific tag
func has_tag(tag: String) -> bool:
	return tag in tags

## Check if this event conflicts with another based on type
func conflicts_with(other: EventData) -> bool:
	# STORY_MOMENT blocks everything except SPOOKY_BRIEF
	if event_type == "STORY_MOMENT" and other.event_type != "SPOOKY_BRIEF":
		return true
	if other.event_type == "STORY_MOMENT" and event_type != "SPOOKY_BRIEF":
		return true
	
	# Same type events conflict (except NONE)
	if event_type != "NONE" and event_type == other.event_type:
		return true
	
	return false

## Calculate modified cost based on occurrences
func get_modified_cost(occurrences: int) -> int:
	# Each occurrence reduces cost by 10%
	var modifier = 1.0 - (occurrences * 0.1)
	modifier = max(modifier, 0.1) # Never go below 10% of original cost
	return int(cost * modifier)
