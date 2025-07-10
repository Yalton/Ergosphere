extends EventHandler
class_name TerminalFlickerEvent

## Event that causes a nearby terminal to briefly display cryptic messages

@export_group("Flicker Settings")
## Duration range for how long the message displays
@export var min_duration: float = 1.5
@export var max_duration: float = 3.0
## Maximum distance to find a terminal from the player
@export var max_terminal_distance: float = 10.0
## Group name for diegetic UI elements
@export var diegetic_ui_group: String = "diegetic_ui"

@export_group("Message Override")
## If not empty, use this specific message instead of the screen's random ones
@export var override_message: String = ""

var affected_terminal: Node = null
var flicker_duration: float = 0.0

func _ready() -> void:
	super._ready()
	module_name = "TerminalFlickerEvent"
	
	# Define which events this handler processes
	handled_event_ids = ["terminal_flicker", "screen_flicker", "message_flicker"]
	
	DebugLogger.debug(module_name, "TerminalFlickerEvent ready")

func can_execute() -> bool:
	# First check base requirements
	if not super.can_execute():
		return false
	
	# Find nearest terminal to player
	var nearest_terminal = _find_nearest_terminal()
	if not nearest_terminal:
		DebugLogger.warning(module_name, "No valid terminal found near player")
		return false
	
	return true

func execute() -> bool:
	# Call base implementation
	if not super.execute():
		return false
	
	# Find nearest terminal
	affected_terminal = _find_nearest_terminal()
	if not affected_terminal:
		DebugLogger.error(module_name, "No terminal found during execution")
		return false
	
	# Get the UI content from the terminal
	var ui_content = affected_terminal.ui_content
	if not ui_content:
		DebugLogger.error(module_name, "Terminal has no ui_content: " + affected_terminal.name)
		return false
	
	# Check if it has a corruption screen configured
	if not ui_content.corruption_screen:
		DebugLogger.error(module_name, "Terminal UI content has no corruption_screen configured")
		return false
	
	# Get random duration
	flicker_duration = randf_range(min_duration, max_duration)
	
	DebugLogger.info(module_name, "Flickering terminal: " + affected_terminal.name + " for " + str(flicker_duration) + " seconds")
	
	# If corruption screen is a TerminalFlickerScreen, configure it
	if ui_content.corruption_screen is TerminalFlickerScreen:
		var flicker_screen = ui_content.corruption_screen as TerminalFlickerScreen
		if not override_message.is_empty():
			flicker_screen.show_message(override_message)
		else:
			flicker_screen.show_message()  # Use random message
	
	# Show the corruption screen
	ui_content.show_corruption()
	
	# Hide after duration
	get_tree().create_timer(flicker_duration).timeout.connect(func():
		if is_active and ui_content:
			ui_content.hide_corruption()
			end()
	)
	
	return true

func _find_nearest_terminal() -> Node:
	var player = GameManager.get_player()
	if not player:
		return null
	
	var ui_elements = get_tree().get_nodes_in_group(diegetic_ui_group)
	var nearest_terminal = null
	var nearest_distance = max_terminal_distance
	
	for ui in ui_elements:
		if not ui.is_inside_tree():
			continue
			
		# Skip if terminal is disabled or corrupted
		if ui.is_disabled or ui.is_corrupted:
			continue
			
		var distance = player.global_position.distance_to(ui.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_terminal = ui
	
	return nearest_terminal

func end() -> void:
	DebugLogger.info(module_name, "Terminal flicker event completed on: " + (affected_terminal.name if affected_terminal else "unknown"))
	
	affected_terminal = null
	
	# Call base implementation
	super.end()
