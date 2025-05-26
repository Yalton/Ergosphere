# GameManager.gd
extends Node

# Singleton reference

@export var enable_debug: bool = true
var module_name: String = "GameManager"

# Manager references
var event_manager: EventManager
var state_manager: StateManager

# Test controls
@export var test_power_outage_delay: float = 5.0
@export var auto_start_test: bool = false

func _ready() -> void:
	# Set up singleton
	
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	
	# Find managers
	event_manager = get_node("EventManager")
	state_manager = get_node("StateManager")
	
	if not event_manager:
		DebugLogger.error(module_name, "EventManager not found!")
		return
		
	if not state_manager:
		DebugLogger.error(module_name, "StateManager not found!")
		return
	
	# Initialize managers
	event_manager.initialize(state_manager)
	state_manager.initialize()
	
	DebugLogger.info(module_name, "GameManager initialized")
	
	# Test power outage if enabled
	if auto_start_test and test_power_outage_delay > 0:
		var timer = get_tree().create_timer(test_power_outage_delay)
		timer.timeout.connect(_test_power_outage)

func _test_power_outage() -> void:
	DebugLogger.debug(module_name, "Testing power outage")
	trigger_power_outage()

# Public API for triggering events
func trigger_power_outage() -> void:
	DebugLogger.debug(module_name, "Triggering power outage")
	event_manager.trigger_event("power_outage")

func restore_power() -> void:
	DebugLogger.debug(module_name, "Restoring power")
	event_manager.reverse_event("power_outage")

# Called by interactables or other systems
func on_power_lever_interacted() -> void:
	restore_power()

# Get current game state
func is_power_on() -> bool:
	return state_manager.get_state("power") == "on"
