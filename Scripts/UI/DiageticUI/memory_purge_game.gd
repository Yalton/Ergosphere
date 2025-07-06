extends DiageticUIContent
class_name MemoryPurgeGame

signal game_won

# Debug settings
@export var enable_debug: bool = true
var module_name: String = "MemoryPurge"

# Game settings
@export var grid_size: int = 5
@export var initial_corruption_interval: float = 2.0
@export var min_corruption_interval: float = 0.5
@export var corruption_lifetime: float = 5.0
@export var purge_animation_time: float = 0.3
@export var blocks_to_win: int = 50
@export var victory_animation_delay: float = 0.05

# Colors
@export var normal_color: Color = Color.WHITE
@export var corrupted_color: Color = Color(1.0, 0.3, 0.3)
@export var purged_color: Color = Color(0.3, 1.0, 0.3)

# Node references
@onready var start_screen: Control = $MainUI/StartScreen
@onready var game_screen: Control = $MainUI/GameScreen
@onready var start_button: Button = $MainUI/StartScreen/PanelContainer/MarginContainer/VBoxContainer/Button
@onready var counter_label: Label = $MainUI/GameScreen/VBoxContainer/HeaderPanel/VBoxContainer/HBoxContainer/CounterLabel
@onready var progress_bar: ProgressBar = $MainUI/GameScreen/VBoxContainer/HeaderPanel/VBoxContainer/ProgressBar
@onready var grid_container: GridContainer = $MainUI/GameScreen/VBoxContainer/GamePanel/MarginContainer/GridContainer

# Game state
var memory_blocks: Array[Button] = []
var block_states: Dictionary = {} # block -> {"corrupted": bool, "corruption_timer": float}
var blocks_purged: int = 0
var corruption_timer: Timer
var current_corruption_interval: float
var is_game_active: bool = false

func _ready() -> void:
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	
	# Set up UI
	game_screen.hide()
	start_screen.show()
	
	# Connect start button
	start_button.pressed.connect(_on_start_pressed)
	
	# Create corruption timer
	corruption_timer = Timer.new()
	corruption_timer.timeout.connect(_corrupt_random_block)
	add_child(corruption_timer)
	
	# Set up grid
	grid_container.columns = grid_size
	_create_memory_blocks()
	
	# Set up progress bar
	if progress_bar:
		progress_bar.max_value = blocks_to_win
		progress_bar.value = 0
	
	DebugLogger.debug(module_name, "Memory Purge game initialized")

func _create_memory_blocks() -> void:
	# Don't create new blocks - use existing ones from the scene
	memory_blocks.clear()
	block_states.clear()
	
	# Find all existing buttons in the grid
	for child in grid_container.get_children():
		if child is Button:
			memory_blocks.append(child)
			
			# Connect click signal if not already connected
			if not child.pressed.is_connected(_on_block_clicked):
				child.pressed.connect(_on_block_clicked.bind(child))
			
			# Initialize state
			block_states[child] = {
				"corrupted": false,
				"corruption_timer": 0.0
			}
			
			# Set initial color
			child.modulate = normal_color
	
	DebugLogger.debug(module_name, "Found " + str(memory_blocks.size()) + " memory blocks")

func _on_start_pressed() -> void:
	DebugLogger.debug(module_name, "Starting game")
	
	# Play neutral sound for game start
	play_neutral_sound()
	
	# Switch screens
	start_screen.hide()
	game_screen.show()
	
	# Reset game state
	blocks_purged = 0
	current_corruption_interval = initial_corruption_interval
	_update_counter()
	_update_progress()
	
	# Reset all blocks
	for block in memory_blocks:
		block.modulate = normal_color
		block.disabled = false
		block_states[block]["corrupted"] = false
		block_states[block]["corruption_timer"] = 0.0
	
	# Start game
	is_game_active = true
	corruption_timer.start(current_corruption_interval)
	
	# Corrupt first block immediately
	_corrupt_random_block()

func _corrupt_random_block() -> void:
	if not is_game_active:
		return
	
	# Find non-corrupted blocks
	var available_blocks: Array[Button] = []
	for block in memory_blocks:
		if not block_states[block]["corrupted"]:
			available_blocks.append(block)
	
	# If all blocks are corrupted, skip
	if available_blocks.is_empty():
		DebugLogger.debug(module_name, "All blocks corrupted, skipping corruption cycle")
		return
	
	# Pick random block to corrupt
	var block = available_blocks[randi() % available_blocks.size()]
	_corrupt_block(block)
	
	# Speed up corruption rate slightly
	current_corruption_interval = max(min_corruption_interval, current_corruption_interval * 0.98)
	corruption_timer.wait_time = current_corruption_interval

func _corrupt_block(block: Button) -> void:
	if block_states[block]["corrupted"]:
		return
		
	block_states[block]["corrupted"] = true
	block_states[block]["corruption_timer"] = corruption_lifetime
	
	# Animate corruption
	var tween = create_tween()
	tween.tween_property(block, "modulate", corrupted_color, 0.2)
	
	# Play negative sound for corruption
	play_negative_sound()
	
	DebugLogger.debug(module_name, "Corrupted block: " + block.name)

func _on_block_clicked(block: Button) -> void:
	if not is_game_active:
		return
		
	if not block_states[block]["corrupted"]:
		# Clicking non-corrupted block - play negative feedback
		play_negative_sound()
		return
	
	# Purge the corrupted block - play positive feedback
	play_positive_sound()
	_purge_block(block)

func _purge_block(block: Button) -> void:
	block_states[block]["corrupted"] = false
	block_states[block]["corruption_timer"] = 0.0
	
	# Increment counter
	blocks_purged += 1
	_update_counter()
	_update_progress()
	
	# Animate purge
	var tween = create_tween()
	tween.tween_property(block, "modulate", purged_color, 0.1)
	tween.tween_property(block, "modulate", normal_color, purge_animation_time)
	
	DebugLogger.debug(module_name, "Purged block: " + block.name + ", Total: " + str(blocks_purged))
	
	# Check win condition
	if blocks_purged >= blocks_to_win:
		_trigger_victory()

func _update_counter() -> void:
	counter_label.text = str(blocks_purged) + "/" + str(blocks_to_win)

func _update_progress() -> void:
	if progress_bar:
		progress_bar.value = blocks_purged

func _process(delta: float) -> void:
	if not is_game_active:
		return
	
	# Update corruption timers
	for block in memory_blocks:
		if block_states[block]["corrupted"]:
			block_states[block]["corruption_timer"] -= delta
			
			# Auto-cleanse if corruption timer expires
			if block_states[block]["corruption_timer"] <= 0:
				_auto_cleanse_block(block)

func _auto_cleanse_block(block: Button) -> void:
	block_states[block]["corrupted"] = false
	block_states[block]["corruption_timer"] = 0.0
	
	# Just fade back to normal (no purge animation)
	var tween = create_tween()
	tween.tween_property(block, "modulate", normal_color, 0.5)
	
	DebugLogger.debug(module_name, "Auto-cleansed block: " + block.name)

## Public method to stop the game (useful for when UI is closed)
func stop_game() -> void:
	is_game_active = false
	corruption_timer.stop()
	DebugLogger.debug(module_name, "Game stopped")

## Public method to check if game is running
func is_running() -> bool:
	return is_game_active

func _trigger_victory() -> void:
	DebugLogger.debug(module_name, "Victory! Starting victory animation")
	
	# Stop the game
	is_game_active = false
	corruption_timer.stop()
	
	# Disable all blocks
	for block in memory_blocks:
		block.disabled = true
		block.modulate = normal_color
		block_states[block]["corrupted"] = false
	
	# Play victory sound
	play_victory_sound()
	
	# Start victory animation
	_play_victory_animation()

func _play_victory_animation() -> void:
	# Animate blocks from top-left to bottom-right
	for i in range(memory_blocks.size()):
		var block = memory_blocks[i]
		
		# Calculate delay based on position (left to right, top to bottom)
		var delay = i * victory_animation_delay
		
		# Create tween for this block
		var tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_property(block, "modulate", purged_color, 0.2)
	
	# Show completion message after animation
	var total_animation_time = memory_blocks.size() * victory_animation_delay + 0.5
	var completion_timer = get_tree().create_timer(total_animation_time)
	completion_timer.timeout.connect(_on_victory_complete)

func _on_victory_complete() -> void:
	DebugLogger.info(module_name, "Memory purge complete!")
	game_won.emit()
	# Could show a completion message or return to start screen here
