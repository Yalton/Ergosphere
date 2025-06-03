# DayConfigResource.gd
extends Resource
class_name DayConfigResource

## Which day number this config is for (1, 2, 3, etc). Multiple configs can have same day_number if they have different requires_flags.
@export var day_number: int = 1

## Optional friendly name for this day, like "First Day" or "Emergency Protocol Day". Shown in debug logs.
@export var day_name: String = ""

# Tasks for this day
## Pool of tasks that CAN be assigned this day. Leave empty to use TaskManager's default_available_tasks.
@export var available_tasks: Array[BaseTask] = []

## Task IDs that MUST be included in today's tasks. Example: ["check_systems", "eat_breakfast"]
@export var mandatory_tasks: Array[String] = []

## Task IDs to exclude from today's pool. Example: ["repair_engine"] if engine isn't broken yet.
@export var excluded_tasks: Array[String] = []

## Override the number of tasks assigned today. Set to -1 to use TaskManager's default_tasks_per_day.
@export var task_count_override: int = -1

# Events for this day (event nodes are defined as children of EventManager)
## Event node names that CAN trigger today. Leave empty to allow all events.
@export var available_event_ids: Array[String] = []

## Event IDs that WILL trigger at day start. Example: ["power_outage"] for scripted failure.
@export var guaranteed_events: Array[String] = []

## Event IDs that CAN'T trigger today. Example: ["alien_attack"] on tutorial day.
@export var excluded_events: Array[String] = []

# Special conditions
## Override game states at day start. Example: {"power": "off", "emergency_mode": true}
@export var starting_states: Dictionary = {}

## Message shown to player when day starts. Example: "Day 3: The reactor is acting strange..."
@export var intro_message: String = ""

## Message shown when all daily tasks are complete. Example: "You survived another day!"
@export var completion_message: String = ""

# Story flags
## Story flags to set when this day is completed. Used for branching narratives. Example: ["discovered_sabotage"]
@export var sets_flags: Array[String] = []

## Story flags that must exist for this day config to be used. Example: ["chose_investigate_noise"]
@export var requires_flags: Array[String] = []
