extends BaseSnappable
class_name Terminal

@export var animation_player: AnimationPlayer
@export var snap_sound: AudioStream


func _ready() -> void:
	# Call parent _ready
	super._ready()
	module_name = "Terminal"
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	
	# Find task aware component
	task_aware_component = get_node_or_null("TaskAwareComponent")
	
	# Add to upload_terminals group for task system
	add_to_group("upload_terminals")
	
	# Connect to GameManager task completion to check when download_data is done
	if GameManager and GameManager.task_manager:
		GameManager.task_manager.task_completed.connect(_on_task_completed)
	
	# Initial check of snappability
	_update_snappability()
	
	DebugLogger.debug(module_name, "Terminal initialized")

func _on_task_completed(task_id: String) -> void:
	if task_id == "download_data":
		_update_snappability()

func _update_snappability() -> void:
	# Only allow snapping if download_data task is completed
	if GameManager and GameManager.task_manager:
		var download_completed = GameManager.task_manager.is_task_completed("download_data")
		can_snap = download_completed
		
		DebugLogger.debug(module_name, "Updated snappability - can_snap: " + str(can_snap))

# Override the parent method to implement specific behavior
func _on_object_snapped(_object_name: String, _object_node: Node3D) -> void:
	DebugLogger.debug(module_name, "Object snapped to Terminal: " + _object_name)
	
	if animation_player:
		animation_player.play("drive_insert")
	
	# Complete the upload task
	if task_aware_component:
		task_aware_component.complete_task()
