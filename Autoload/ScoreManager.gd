# high_score_manager.gd
extends Node

const SAVE_FILE_PATH = "user://high_score.save"
var high_score: int = 0

func _ready() -> void:
	load_high_score()

# Load high score from save file
func load_high_score() -> int:
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		high_score = file.get_32()
		file.close()
		print("Loaded high score: ", high_score)
	else:
		print("No high score file found, using default value: 0")
		high_score = 0
	
	return high_score

# Save high score to file
func save_high_score(score: int) -> bool:
	# Only save if the new score is higher than the current high score
	if score > high_score:
		high_score = score
		var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
		if file:
			file.store_32(high_score)
			file.close()
			print("New high score saved: ", high_score)
			return true
	
	return false

# Check if a score is a new high score
func is_new_high_score(score: int) -> bool:
	return score > high_score

# Get the current high score
func get_high_score() -> int:
	return high_score
