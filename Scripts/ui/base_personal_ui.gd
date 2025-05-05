extends Control
class_name BasePersonalUI

# Debug properties
@export var enable_debug: bool = true
var module_name: String = "BaseUI"

# Visibility signals
signal ui_opened
signal ui_closed

# Behavior flags
@export var disable_player_movement: bool = true
@export var disable_weapon_firing: bool = true
@export var allow_pause_inputs: bool = false

# Reference to player
var player: Player = null
var previous_player_state_cache: Dictionary = {}

func _ready() -> void:
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	
	# Find player reference
	player = _find_player()
	
	# Initially hide UI
	visible = false
	
	# Call implementation-specific setup
	_setup()
	
	DebugLogger.debug(module_name, "BaseUI initialized")

# Virtual method for implementation-specific setup
func _setup() -> void:
	pass

# Find reference to the player (parent)
func _find_player() -> Player:
	# Try to find player up the tree
	var current = get_parent()
	while current:
		if current is Player:
			return current
		current = current.get_parent()
	
	DebugLogger.warning(module_name, "Could not find player reference")
	return null

# Show UI with proper player state management
func show_ui() -> void:
	if visible:
		return
		
	# Cache player state before modifying it
	_cache_player_state()
	
	# Apply player restrictions based on UI flags
	_apply_player_restrictions()
	
	# Show the UI
	visible = true
	
	# Call implementation-specific show logic
	_on_show()
	
	# Emit signals
	ui_opened.emit()
	visibility_changed.emit(true)
	
	DebugLogger.debug(module_name, "UI shown")

# Hide UI with proper player state restoration
func hide_ui() -> void:
	if !visible:
		return
		
	# Restore player state from cache
	_restore_player_state()
	
	# Hide the UI
	visible = false
	
	# Call implementation-specific hide logic
	_on_hide()
	
	# Emit signals
	ui_closed.emit()
	visibility_changed.emit(false)
	
	DebugLogger.debug(module_name, "UI hidden")

# Toggle UI visibility
func toggle_ui() -> void:
	if visible:
		hide_ui()
	else:
		show_ui()

# Cache player state before applying restrictions
func _cache_player_state() -> void:
	if !player:
		return
		
	previous_player_state_cache["can_control"] = player.can_control
	previous_player_state_cache["input_disabled"] = player.input_disabled if "input_disabled" in player else false
	
	DebugLogger.debug(module_name, "Cached player state")

# Apply restrictions to player based on UI flags

func _apply_player_restrictions() -> void:
	if !player:
		return
		
	if disable_player_movement:
		# DON'T disable physics completely - only input control
		# We don't want to call set_can_control(false) directly as it might stop physics
		
		# Instead, set input_disabled flag to prevent control input
		# while keeping physics running
		if "input_disabled" in player:
			player.input_disabled = true
			DebugLogger.debug(module_name, "Set player input_disabled to true")
	
	if disable_weapon_firing && player.weapons_manager:
		# If the weapon manager has a disable_firing method, call it
		if player.weapons_manager.has_method("disable_firing"):
			player.weapons_manager.disable_firing()
	
	DebugLogger.debug(module_name, "Applied player restrictions (keeping physics active)")

# Restore player state from cache
func _restore_player_state() -> void:
	if !player or previous_player_state_cache.is_empty():
		return
		
	# Restore control
	if previous_player_state_cache.has("can_control"):
		player.set_can_control(previous_player_state_cache["can_control"])
	
	# Restore input flag
	if previous_player_state_cache.has("input_disabled") and "input_disabled" in player:
		player.input_disabled = previous_player_state_cache["input_disabled"]
	
	# If we were restricting weapons, re-enable them
	if disable_weapon_firing && player.weapons_manager:
		if player.weapons_manager.has_method("enable_firing"):
			player.weapons_manager.enable_firing()
	
	DebugLogger.debug(module_name, "Restored player state")

# Virtual method for implementation-specific show logic
func _on_show() -> void:
	pass

# Virtual method for implementation-specific hide logic
func _on_hide() -> void:
	pass

# Process input events for UI navigation
func _input(event: InputEvent) -> void:
	# Implementation-specific input handling
	_handle_input(event)

# Virtual method for implementation-specific input handling
func _handle_input(event: InputEvent) -> void:
	pass
