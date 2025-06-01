# PowerLever.gd
extends GameObject

signal power_restored
signal object_state_updated(interaction_text: String)

@export var enable_debug: bool = true
var module_name: String = "PowerLever"

@export_group("Lever Settings")
@export var lever_animation_player: AnimationPlayer
@export var power_on_animation: String = "power_on"
@export var power_off_animation: String = "power_off"

# Internal state
var is_powered: bool = true
var is_interacting: bool = false
var task_aware_component: TaskAwareComponent

func _ready() -> void:
	super._ready()  # Call GameObject's _ready()
	
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
		if powered and lever_animation_player.has_animation(power_on_animation):
			lever_animation_player.play(power_on_animation)
		elif not powered and lever_animation_player.has_animation(power_off_animation):
			lever_animation_player.play(power_off_animation)
	
	# Let task component handle interaction text
	if not task_aware_component:
		# Fallback if no task component
		if is_powered:
			object_state_updated.emit("Power is already on")
		else:
			object_state_updated.emit("Pull lever to restore power")
	
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
		player_interaction.send_message("Power is already on")
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
	# Tell game manager to restore power
	if GameManager:
		GameManager.restore_power()
	else:
		DebugLogger.error(module_name, "GameManager instance not found!")
	
	is_powered = true
	is_interacting = false
	
	# The task component will handle updating interaction text
	
	# Emit signal
	power_restored.emit()
	
	DebugLogger.info(module_name, "Power restored via lever")
