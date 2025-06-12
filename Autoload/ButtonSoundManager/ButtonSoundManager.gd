# ButtonSoundManager.gd
extends Node

# Default sound that will be played when any button is clicked
@export var default_click_sound: AudioStream

# Enable debug logging
@export var enable_debug: bool = false
@export var module_name: String = "ButtonSoundManager"

# Button group name
const SOUND_BUTTON_GROUP = "sound_buttons"

func _ready() -> void:

	DebugLogger.register_module(module_name, enable_debug)
	
	# Set to always process even when game is paused
	process_mode = PROCESS_MODE_ALWAYS
	
	# Connect to the node_added signal to catch any buttons added during gameplay
	get_tree().node_added.connect(_on_node_added)
	
	# Process existing buttons in the scene
	_process_existing_buttons()

func _process_existing_buttons() -> void:
	DebugLogger.debug(module_name, "Processing existing buttons")
	
	# Get all buttons already in the sound_buttons group
	var buttons = get_tree().get_nodes_in_group(SOUND_BUTTON_GROUP)
	
	for button in buttons:
		_connect_button(button)

func _on_node_added(node: Node) -> void:
	# Check if the newly added node is a button in our group
	if node is Button and node.is_in_group(SOUND_BUTTON_GROUP):
		_connect_button(node)

func _connect_button(button: Button) -> void:
	# Only connect if not already connected
	if not button.pressed.is_connected(_play_click_sound):
		button.pressed.connect(_play_click_sound)
		DebugLogger.debug(module_name, "Connected button: " + button.name)
		
		# Ensure the button also processes during pause
		button.process_mode = Node.PROCESS_MODE_ALWAYS

func _play_click_sound() -> void:
	if default_click_sound:
		Audio.play_sound(default_click_sound)
		DebugLogger.debug(module_name, "Played button click sound")

# Public method to add a button to the sound system
func add_button(button: Button) -> void:
	if not button.is_in_group(SOUND_BUTTON_GROUP):
		button.add_to_group(SOUND_BUTTON_GROUP)
	_connect_button(button)
