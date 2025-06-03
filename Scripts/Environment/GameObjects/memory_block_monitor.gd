extends DiegeticUIBase
class_name MemoryPurgeTerminal

signal memory_purge_completed

# This goes in the SubViewport of your DiegeticUIBase

@onready var memory_game: MemoryPurgeGame = $SubViewport/memory_purge_game


func _ready() -> void:
	super._ready()
	module_name = "MemoryPurgeTerminal"
	
	# Find task aware component
	task_aware_component = get_node_or_null("TaskAwareComponent")
	
	# Add to memory_terminals group for task system
	add_to_group("memory_terminals")
	
	# Connect to the game's victory signal
	if memory_game:
		memory_game.game_won.connect(_on_game_won)

func _on_game_won() -> void:
	DebugLogger.info(module_name, "Memory purge game won, completing task")
	
	# Complete the task if we have a task component
	if task_aware_component:
		task_aware_component.complete_task()
	
	# Propagate signal
	memory_purge_completed.emit()
