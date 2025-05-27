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
@export var test_oxygen_failure_delay: float = 5.0
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
	
	# Test events if enabled
	if auto_start_test:
		if test_power_outage_delay > 0:
			var power_timer = get_tree().create_timer(test_power_outage_delay)
			power_timer.timeout.connect(_test_power_outage)
		
		if test_oxygen_failure_delay > 0:
			var oxygen_timer = get_tree().create_timer(test_oxygen_failure_delay)
			oxygen_timer.timeout.connect(_test_oxygen_failure)

func _test_power_outage() -> void:
	DebugLogger.debug(module_name, "Testing power outage")
	trigger_power_outage()

func _test_oxygen_failure() -> void:
	DebugLogger.debug(module_name, "Testing oxygen failure")
	trigger_oxygen_failure()

# Public API for triggering events
func trigger_power_outage() -> void:
	DebugLogger.debug(module_name, "Triggering power outage")
	event_manager.trigger_event("power_outage")

func trigger_oxygen_failure() -> void:
	DebugLogger.debug(module_name, "Triggering oxygen failure")
	event_manager.trigger_event("oxygen_failure")

func restore_power() -> void:
	DebugLogger.debug(module_name, "Restoring power")
	event_manager.reverse_event("power_outage")

# Called by interactables or other systems
func on_power_lever_interacted() -> void:
	restore_power()

# Get current game state
func is_power_on() -> bool:
	return state_manager.get_state("power") == "on"
