extends InteractionComponent

signal is_being_held(time_left:float)
signal hold_completed

@export var hold_time : float = 3.0

@onready var parent_node : Node = get_parent()
@onready var hold_timer: Timer = $HoldTimer
@onready var hold_ui: Control = $HoldUi
@onready var progress_bar: ProgressBar = $HoldUi/ProgressBar

var is_holding : bool = false
var player_interaction_component : PlayerInteractionComponent

func _ready() -> void:
	hold_ui.hide()
	hold_timer.timeout.connect(_on_hold_complete)
	hold_timer.wait_time = hold_time
	progress_bar.max_value = 100

func interact(_player_interaction_component : PlayerInteractionComponent) -> void:
	player_interaction_component = _player_interaction_component
	if !is_holding:
		is_holding = true
		hold_ui.show()
		hold_timer.start()

func _process(_delta: float) -> void:
	if is_holding:
		var time_left = hold_timer.time_left
		is_being_held.emit(time_left)
		progress_bar.value = (1 - time_left / hold_time) * 100
		
		var interaction_distance : float = (parent_node.global_position - player_interaction_component.global_position).length()
		if interaction_distance >= player_interaction_component.interaction_raycast.target_position.length():
			_cancel_hold()

func _input(event : InputEvent) -> void:
	if is_holding and event.is_action_released("interact"):
		_cancel_hold()

func _cancel_hold() -> void:
	hold_timer.stop()
	hold_ui.hide()
	is_holding = false

func _on_hold_complete() -> void:
	hold_timer.stop()
	hold_ui.hide()
	is_holding = false
	emit_signal("hold_completed")

func _on_object_state_change(_interaction_text: String) -> void:
	# This function seems unused, but keeping it for compatibility
	pass
