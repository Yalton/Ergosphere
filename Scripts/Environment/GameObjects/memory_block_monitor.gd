extends DiegeticUIBase
class_name MemoryPurgeTerminal

signal memory_purge_completed

# This goes in the SubViewport of your DiegeticUIBase

@onready var memory_game: MemoryPurgeGame = $SubViewport/memory_purge_game

func _ready() -> void:
	super._ready()
	module_name = "MemoryPurgeTerminal"
	
	# Connect to the game's victory signal
	if memory_game:
		memory_game.game_won.connect(_on_game_won)

#func _on_show() -> void:
	## Called when the diegetic UI is opened
	## Game will auto-start when player clicks the button
	#pass
#
#func _on_hide() -> void:
	## Called when the diegetic UI is closed
	#if memory_game and memory_game.is_running():
		#memory_game.stop_game()

func _on_game_won() -> void:
	DebugLogger.info(module_name, "Memory purge game won, propagating signal")
	memory_purge_completed.emit()
