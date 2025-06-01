# DayConfigResource.gd
extends Resource
class_name DayConfigResource

@export var day_number: int = 1
@export var day_name: String = ""  # Optional, like "First Day" or "Emergency Protocol Day"

# Tasks for this day
@export var available_tasks: Array[BaseTask] = []
@export var mandatory_tasks: Array[String] = []  # Task IDs that MUST be assigned
@export var excluded_tasks: Array[String] = []  # Task IDs to exclude
@export var task_count_override: int = -1  # -1 uses default, otherwise override

# Events for this day (event nodes are defined as children of EventManager)
@export var available_event_ids: Array[String] = []  # Event node names that CAN happen
@export var guaranteed_events: Array[String] = []  # Event IDs that WILL happen
@export var excluded_events: Array[String] = []  # Event IDs that CAN'T happen

# Special conditions
@export var starting_states: Dictionary = {}  # Override default states for this day
@export var intro_message: String = ""  # Message to show at day start
@export var completion_message: String = ""  # Message on day complete

# Story flags
@export var sets_flags: Array[String] = []  # Flags to set when day completes
@export var requires_flags: Array[String] = []  # Flags needed to play this day
