extends Node
class_name InsanityComponent

signal insanity_changed(new_value: float)

## Current insanity level (0-100)
@export var current_insanity: float = 0.0

## Base insanity gain per second
@export var base_insanity_gain: float = 0.5

## Percentage of insanity removed when eating
@export var eating_reduction_percent: float = 0.8

## Grace period after reset/reduction where insanity can't increase
@export var grace_period_duration: float = 10.0

## Amount of insanity added when events trigger
@export var event_insanity_gain: float = 5.0

var grace_period_timer: float = 0.0
var player: Node = null
var interaction_component: PlayerInteractionComponent = null

func _ready():
	DebugLogger.register_module("InsanityComponent")
	set_process(true)
	
	# Get player reference
	player = CommonUtils.get_player()
	if player:
		interaction_component = player.interaction_component

func _process(delta):
	# Update grace period
	if grace_period_timer > 0:
		grace_period_timer -= delta
		return
	
	# Check if we should accumulate insanity
	if _should_accumulate_insanity():
		add_insanity(base_insanity_gain * delta)

func _should_accumulate_insanity() -> bool:
	# Don't accumulate if game is paused
	if get_tree().paused:
		return false
	
	# Don't accumulate if interacting with diegetic UI
	if interaction_component and interaction_component.is_interacting_with_ui:
		return false
	
	return true

func add_insanity(amount: float):
	# Skip if in grace period
	if grace_period_timer > 0 and amount > 0:
		return
	
	var old_insanity = current_insanity
	current_insanity = clamp(current_insanity + amount, 0.0, 100.0)
	
	if current_insanity != old_insanity:
		insanity_changed.emit(current_insanity)
		DebugLogger.log_message("InsanityComponent", "Insanity: %.2f" % current_insanity)

func reset_insanity():
	current_insanity = 0.0
	grace_period_timer = grace_period_duration
	insanity_changed.emit(current_insanity)
	DebugLogger.log_message("InsanityComponent", "Insanity reset, grace period: %.1fs" % grace_period_duration)

func reduce_insanity_by_eating():
	var reduction = current_insanity * eating_reduction_percent
	current_insanity = max(0.0, current_insanity - reduction)
	grace_period_timer = grace_period_duration
	insanity_changed.emit(current_insanity)
	DebugLogger.log_message("InsanityComponent", "Reduced insanity by %.2f, grace period: %.1fs" % [reduction, grace_period_duration])

func add_event_insanity():
	add_insanity(event_insanity_gain)

func get_event_cooldown_multiplier() -> float:
	# Higher insanity = lower cooldown (more frequent events)
	return 1.0 - (current_insanity / 100.0) * 0.8  # At max insanity, cooldown is 20% of normal

func get_event_chance_multiplier() -> float:
	# Higher insanity = higher chance
	return 1.0 + (current_insanity / 100.0) * 2.0  # At max insanity, 3x chance
