# AwareGameObject.gd
extends GameObject
class_name AwareGameObject

signal awareness_state_changed(can_interact: bool, reason: String)

@export var enable_debug: bool = true
var module_name: String = "AwareGameObject"

# Awareness components
var task_aware_component: TaskAwareComponent
var state_aware_component: StateAwareComponent

# Control flags
var is_task_blocked: bool = false
var is_state_blocked: bool = false
var block_reason: String = ""

# Optional components to disable
var interaction_components: Array[InteractionComponent] = []
var snap_components: Array[SnapComponent] = []
var audio_players: Array[AudioStreamPlayer3D] = []
var animation_players: Array[AnimationPlayer] = []

func _ready() -> void:
	super._ready()
	
	DebugLogger.register_module(module_name, enable_debug)
	
	# Find awareness components
	task_aware_component = get_node_or_null("TaskAwareComponent")
	state_aware_component = get_node_or_null("StateAwareComponent")
	
	# Find components to control
	_find_controllable_components()
	
	# Connect to awareness signals
	if task_aware_component:
		task_aware_component.task_availability_changed.connect(_on_task_availability_changed)
	
	if state_aware_component:
		state_aware_component.state_requirements_changed.connect(_on_state_requirements_changed)
	
	# Initial state check
	_check_awareness_state()
	
	DebugLogger.debug(module_name, "AwareGameObject initialized on " + name)

func _find_controllable_components() -> void:
	# Find all interaction components
	for child in get_children():
		if child is InteractionComponent:
			interaction_components.append(child)
		elif child is SnapComponent:
			snap_components.append(child)
		elif child is AudioStreamPlayer3D:
			audio_players.append(child)
		elif child is AnimationPlayer:
			animation_players.append(child)

func _on_task_availability_changed(is_available: bool) -> void:
	is_task_blocked = not is_available
	
	if is_task_blocked and task_aware_component:
		# Get the current interaction text from task component
		var task_text = task_aware_component.get_interaction_text() 
		if task_text != "":
			block_reason = task_text
	
	_check_awareness_state()

func _on_state_requirements_changed(can_interact: bool, reason: String) -> void:
	is_state_blocked = not can_interact
	
	if is_state_blocked:
		block_reason = reason
	
	_check_awareness_state()

func _check_awareness_state() -> void:
	var can_interact = not is_task_blocked and not is_state_blocked
	
	# Update all components based on awareness state
	_set_components_enabled(can_interact)
	
	# Update interaction text
	if not can_interact and block_reason != "":
		object_state_updated.emit(block_reason)
	
	# Emit signal
	awareness_state_changed.emit(can_interact, block_reason)
	
	DebugLogger.debug(module_name, "Awareness state changed - Can interact: " + str(can_interact) + ", Reason: " + block_reason)

func _set_components_enabled(enabled: bool) -> void:
	# Disable/enable interaction components
	for component in interaction_components:
		component.is_disabled = not enabled
	
	# Disable/enable snap components
	for component in snap_components:
		if "can_snap" in component:
			component.can_snap = enabled
	
	# Mute/unmute audio players if needed
	if not enabled:
		for audio in audio_players:
			if audio.playing:
				audio.stop()
	
	# Special handling for diegetic UI
	if self is DiegeticUIBase:
		# Update the interaction text based on availability
		if not enabled:
			usable_interaction_text = block_reason
		else:
			# Reset to original text (you might want to store this)
			usable_interaction_text = "Use " + display_name

# Override interact to check awareness
func interact(player_interaction: PlayerInteractionComponent) -> void:
	if is_task_blocked or is_state_blocked:
		DebugLogger.debug(module_name, "Interaction blocked: " + block_reason)
		player_interaction.send_message(block_reason)
		return
	
	# Call parent interact
	super.interact(player_interaction)

# Public methods
func set_enabled(enabled: bool, reason: String = "") -> void:
	if not enabled:
		is_state_blocked = true
		block_reason = reason if reason != "" else "Disabled"
	else:
		is_state_blocked = false
		block_reason = ""
	
	_check_awareness_state()

func is_aware_enabled() -> bool:
	return not is_task_blocked and not is_state_blocked
