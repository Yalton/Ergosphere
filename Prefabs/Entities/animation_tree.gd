extends AnimationTree
class_name IconoclastAnimationController

## Tracks which idle animation was used last (main or alt)
var last_idle_was_main: bool = true
## Tracks which walk animation was used last (main or alt)  
var last_walk_was_main: bool = true
## Current animation speed scale
var current_speed_scale: float = 1.0

func _ready():
	DebugLogger.register_module("IconoclastAnimationController")
	# Start in idle state
	set_to_idle()

func set_to_idle():
	# Switch to idle state
	set("parameters/main_transition/transition_request", "idle")
	
	# Alternate between main and alt idle
	if last_idle_was_main:
		set("parameters/idle_trans/transition_request", "alt")
		DebugLogger.log_message("IconoclastAnimationController", "Playing alt idle")
	else:
		set("parameters/idle_trans/transition_request", "main")
		DebugLogger.log_message("IconoclastAnimationController", "Playing main idle")
	
	last_idle_was_main = !last_idle_was_main

func set_to_walk():
	# Switch to walk state
	set("parameters/main_transition/transition_request", "walking")
	
	# Alternate between main and alt walk
	if last_walk_was_main:
		set("parameters/walk_trans/transition_request", "alt")
		DebugLogger.log_message("IconoclastAnimationController", "Playing alt walk")
	else:
		set("parameters/walk_trans/transition_request", "main")
		DebugLogger.log_message("IconoclastAnimationController", "Playing main walk")
	
	last_walk_was_main = !last_walk_was_main

func trigger_reach_out():
	# Fire the reach_out oneshot animation
	set("parameters/reach_out/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	DebugLogger.log_message("IconoclastAnimationController", "Triggered reach_out animation")

func set_speed_scale(scale: float):
	# Set the animation speed scale
	current_speed_scale = scale
	set("parameters/SlowdownScale/scale", scale)
	DebugLogger.log_message("IconoclastAnimationController", "Set animation speed scale to: %.2f" % scale)

func reset_speed_scale():
	# Reset speed scale back to normal
	set_speed_scale(1.0)
