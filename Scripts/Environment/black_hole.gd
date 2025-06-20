# BlackHole.gd
extends Node3D
class_name BlackHole

## Time in seconds the player has been looking at the black hole
@export var view_time: float = 0.0

## How long the player has been looking at it in the current session
@export var current_view_time: float = 0.0

## Whether the black hole is currently visible on screen
@export var is_visible: bool = false

## Time required to trigger the effect (in seconds)
@export var stare_duration_required: float = 10.0

## Cooldown time before effect can trigger again (in seconds)
@export var effect_cooldown: float = 120.0

## Amount to scale the black hole mesh when effect triggers
@export var scale_multiplier: float = 1.2

## Duration of the scale tween animation (in seconds)
@export var tween_duration: float = 2.0

## Amount of sanity to remove when effect triggers
@export var sanity_damage: float = 15.0

@export_group("References")
## The main mesh instance to scale
@export var main_mesh: MeshInstance3D

var module_name: String = "BlackHole"
var effect_on_cooldown: bool = false
var cooldown_timer: float = 0.0
var effect_triggered_this_session: bool = false
var original_scale: Vector3
var scale_tween: Tween

@onready var visible_notifier: VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D

func _ready() -> void:
	# Register with DebugLogger
	DebugLogger.register_module(module_name, true)
	
	# Store original scale
	if main_mesh:
		original_scale = main_mesh.scale
	
	# Connect visibility signals
	if visible_notifier:
		visible_notifier.screen_entered.connect(_on_screen_entered)
		visible_notifier.screen_exited.connect(_on_screen_exited)
		DebugLogger.debug(module_name, "Visibility notifier connected")
	else:
		DebugLogger.error(module_name, "VisibleOnScreenNotifier3D not found as child")

func _process(delta: float) -> void:
	# Update cooldown timer
	if effect_on_cooldown:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			effect_on_cooldown = false
			DebugLogger.debug(module_name, "Effect cooldown ended")
	
	# Track viewing time when visible
	if is_visible:
		current_view_time += delta
		view_time += delta
		
		# Check if we should trigger the effect
		if not effect_on_cooldown and not effect_triggered_this_session:
			if current_view_time >= stare_duration_required:
				_trigger_stare_effect()
		
		# Debug log every 5 seconds
		if int(current_view_time) % 5 == 0 and int(current_view_time) != int(current_view_time - delta):
			DebugLogger.debug(module_name, "Player looking at black hole for: " + str(current_view_time) + "s")

func _trigger_stare_effect() -> void:
	DebugLogger.info(module_name, "Triggering stare effect after " + str(current_view_time) + "s")
	
	effect_triggered_this_session = true
	effect_on_cooldown = true
	cooldown_timer = effect_cooldown
	
	# Tween the mesh scale
	if main_mesh:
		_tween_mesh_scale()
	
	# Damage player sanity
	_damage_player_sanity()
	
	# Send message to player
	if CommonUtils:
		CommonUtils.send_player_message("The void gazes back...", "Black Hole")

func _tween_mesh_scale() -> void:
	# Kill existing tween if any
	if scale_tween and scale_tween.is_valid():
		scale_tween.kill()
	
	# Create new tween
	scale_tween = create_tween()
	scale_tween.set_ease(Tween.EASE_IN_OUT)
	scale_tween.set_trans(Tween.TRANS_SINE)
	
	# Scale up then back down
	var target_scale = original_scale * scale_multiplier
	scale_tween.tween_property(main_mesh, "scale", target_scale, tween_duration * 0.5)
	scale_tween.tween_property(main_mesh, "scale", original_scale, tween_duration * 0.5)
	
	DebugLogger.debug(module_name, "Tweening mesh scale from " + str(original_scale) + " to " + str(target_scale))

func _damage_player_sanity() -> void:
	var player = CommonUtils.get_player()
	if not player:
		DebugLogger.warning(module_name, "Could not find player to damage sanity")
		return
	
	# Try to find insanity component on player
	var insanity_comp = null
	for child in player.get_children():
		if child.has_method("add_insanity"):
			insanity_comp = child
			break
	
	if insanity_comp:
		insanity_comp.add_insanity(sanity_damage)
		DebugLogger.info(module_name, "Damaged player sanity by " + str(sanity_damage))
	else:
		DebugLogger.warning(module_name, "Could not find insanity component on player")

func _on_screen_entered() -> void:
	is_visible = true
	effect_triggered_this_session = false
	DebugLogger.debug(module_name, "Black hole entered screen")

func _on_screen_exited() -> void:
	is_visible = false
	DebugLogger.debug(module_name, "Black hole exited screen - was visible for: " + str(current_view_time) + "s")
	current_view_time = 0.0

func get_total_view_time() -> float:
	return view_time

func get_current_view_time() -> float:
	return current_view_time

func reset_view_time() -> void:
	view_time = 0.0
	current_view_time = 0.0
	DebugLogger.debug(module_name, "View time reset")

func get_cooldown_remaining() -> float:
	if effect_on_cooldown:
		return cooldown_timer
	return 0.0
