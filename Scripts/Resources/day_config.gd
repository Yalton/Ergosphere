# DayConfigResource.gd
extends Resource
class_name DayConfigResource

## Which day number this config is for (1, 2, 3, etc)
@export var day_number: int = 1

## Task IDs that will be assigned for this day. Example: ["check_systems", "eat_breakfast", "sleep"]
@export var task_ids: Array[String] = []
