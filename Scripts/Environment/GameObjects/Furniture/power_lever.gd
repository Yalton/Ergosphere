# PowerLever.gd
extends AwareGameObject

signal power_restored

@export_group("Lever Settings")
@export var lever_animation_player: AnimationPlayer
@export var power_on_animation: String = "power_on"
@export var power_off_animation: String = "power_off"

# Internal state
var is_powered: bool = true
var is_interacting: bool = false

func _ready() -> void:
	super._ready()  # Call GameObject's _ready()
	module_name = "PowerLever"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Set display name if not already set
	if display_name.is_empty():
		display_name = "Power Lever"
	
	# Find task aware component
	task_aware_component = get_node_or_null("TaskAwareComponent")
	
	# Add to power_levers group for task system
	add_to_group("power_levers")
	
	DebugLogger.debug(module_name, "Power lever initialized")

func set_power_state(powered: bool) -> void:
	is_powered = powered
	
	# Play appropriate animation
	if lever_animation_player:
		if not powered and lever_animation_player.has_animation(power_off_animation):
			lever_animation_player.play(power_off_animation)
	
	# Always update interaction text based on power state
	if is_powered:
		object_state_updated.emit("Power is on")
	else:
		object_state_updated.emit("Turn on power")
	
	DebugLogger.debug(module_name, "Power state set to: " + str(powered))

func interact(player_interaction: PlayerInteractionComponent) -> void:
	if is_interacting:
		return
	
	# Let task component check if we can interact
	if task_aware_component and not task_aware_component.is_task_available:
		DebugLogger.debug(module_name, "Task component blocking interaction")
		return
		
	if is_powered:
		# Power is already on
		player_interaction.send_hint("", "Power is already on")
		return
	
	is_interacting = true
	
	# Play power on animation
	if lever_animation_player and lever_animation_player.has_animation(power_on_animation):
		lever_animation_player.play(power_on_animation)
		
		# Wait for animation to finish
		if not lever_animation_player.is_connected("animation_finished", _on_animation_finished):
			lever_animation_player.animation_finished.connect(_on_animation_finished)
	else:
		# No animation, restore power immediately
		_restore_power()

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == power_on_animation:
		_restore_power()

func _restore_power() -> void:
	# Get effects manager to restore power
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if effects_manager:
		effects_manager.restore_power()
		DebugLogger.info(module_name, "Power restored via lever")
	else:
		DebugLogger.error(module_name, "EffectsManager not found!")
	
	# Complete the task if we have a task component
	if task_aware_component:
		task_aware_component.complete_task()
		DebugLogger.debug(module_name, "Task marked as complete")
	
	is_powered = true
	is_interacting = false
	
	# Update interaction text
	object_state_updated.emit("Power is on")
	
	# Emit signal
	power_restored.emit()
