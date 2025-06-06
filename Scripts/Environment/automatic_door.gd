# automatic_station_door.gd
extends Door
class_name AutomaticStationDoor

## Detection area for automatic door opening
@export var detection_area: Area3D

## Delay in seconds before checking if door should close after player exits
@export var close_check_delay: float = 1.0

# Internal tracking
var close_check_timer: Timer
var player_inside: bool = false

func _ready() -> void:
	# Call parent ready
	super._ready()
	
	# Remove from interactable group since it's automatic
	remove_from_group("interactable")
	
	# Force door type to slide vertical
	door_type = DoorType.SLIDE
	slide_direction = Vector3(0, 1, 0)  # Vertical
	
	# Setup detection area
	if not detection_area:
		DebugLogger.error(debug_module_name, "No detection area assigned!")
		return
	
	# Connect area signals
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	
	# Create close check timer
	close_check_timer = Timer.new()
	close_check_timer.wait_time = close_check_delay
	close_check_timer.one_shot = true
	close_check_timer.timeout.connect(_check_and_close_door)
	add_child(close_check_timer)
	
	DebugLogger.debug(debug_module_name, "Automatic station door initialized")

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		
		# Cancel any pending close check
		if close_check_timer.time_left > 0:
			close_check_timer.stop()
			DebugLogger.debug(debug_module_name, "Player entered, cancelled close timer")
		
		# Open door if closed
		if not is_open:
			open_door()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		DebugLogger.debug(debug_module_name, "Player exited, starting close timer")
		
		# Start close check timer
		close_check_timer.start()

func _check_and_close_door() -> void:
	# Get all bodies currently in the detection area
	var bodies_in_area = detection_area.get_overlapping_bodies()
	var player_still_inside = false
	
	# Check if any player is still in the area
	for body in bodies_in_area:
		if body.is_in_group("player"):
			player_still_inside = true
			break
	
	if player_still_inside:
		# Player is still inside, check again later
		DebugLogger.debug(debug_module_name, "Player still inside, checking again in " + str(close_check_delay) + " seconds")
		close_check_timer.start()
	else:
		# No player inside, close the door
		DebugLogger.debug(debug_module_name, "No player detected, closing door")
		close_door()

# Override interact to do nothing (door is automatic)
func interact(_interactor: PlayerInteractionComponent) -> void:
	pass

# Override day reset to also cancel timer
func _on_day_reset() -> void:
	super._on_day_reset()
	
	# Cancel any pending close timer
	if close_check_timer and close_check_timer.time_left > 0:
		close_check_timer.stop()
		
	player_inside = false
