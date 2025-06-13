# TaskTreeUI.gd
extends Tree

signal visibility_state_changed(should_show: bool)

@export var enable_debug: bool = true
var module_name: String = "TaskTreeUI"

# Tree configuration
@export var hide_root_item: bool = true
@export var show_task_descriptions: bool = false
@export var show_emergency_timer: bool = true
@export var auto_hide_when_empty: bool = true
@export var auto_hide_when_complete: bool = true

## Delay in seconds before rebuilding tree after day reset
@export var rebuild_delay_after_reset: float = 5.0

# Styling
@export var completed_color: Color = Color(0.5, 0.5, 0.5)
@export var emergency_color: Color = Color(1.0, 0.3, 0.3)
@export var unavailable_color: Color = Color(0.7, 0.7, 0.7)
@export var available_color: Color = Color(1.0, 1.0, 1.0)

# Icons (optional)
@export var task_icon: Texture2D
@export var completed_icon: Texture2D
@export var emergency_icon: Texture2D
@export var locked_icon: Texture2D

# Task tracking
var task_items: Dictionary = {}  # task_id -> TreeItem
var root_item: TreeItem
var rebuild_timer: Timer

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Configure tree
	hide_root = hide_root_item
	
	# Create root
	root_item = create_item()
	root_item.set_text(0, "Tasks")
	
	# Create rebuild timer
	rebuild_timer = Timer.new()
	rebuild_timer.one_shot = true
	rebuild_timer.timeout.connect(_on_rebuild_timer_timeout)
	add_child(rebuild_timer)
	
	if not GameManager:
		DebugLogger.error(module_name, "GameManager not found")
		return
	
	# Connect to GameManager's day_reset signal
	GameManager.day_reset.connect(_on_day_reset)
	
	# Connect to task manager signals
	if GameManager.task_manager:
		GameManager.task_manager.task_assigned.connect(_on_task_assigned)
		GameManager.task_manager.task_completed.connect(_on_task_completed)
		GameManager.task_manager.emergency_task_triggered.connect(_on_emergency_task_triggered)
		GameManager.task_manager.daily_tasks_completed.connect(_on_daily_tasks_completed)
		GameManager.task_manager.day_started.connect(_on_day_started)
		
		# Check initial state
		_rebuild_tree()
		_check_visibility()
	
	DebugLogger.debug(module_name, "Task Tree UI initialized")

# Update _rebuild_tree to use visible tasks only
func _rebuild_tree() -> void:
	# Clear existing items
	self.clear()
	task_items.clear()
	
	# Recreate root
	root_item = create_item()
	root_item.set_text(0, "Tasks")
	
	if not GameManager or not GameManager.task_manager:
		return
	
	var has_tasks = false
	
	# Add emergency tasks first
	var emergency_tasks = GameManager.task_manager.get_active_emergency_tasks()
	if emergency_tasks.size() > 0:
		var emergency_category = create_item(root_item)
		emergency_category.set_text(0, "EMERGENCY")
		emergency_category.set_custom_color(0, emergency_color)
		emergency_category.set_custom_font_size(0, 16)
		
		for task in emergency_tasks:
			_add_task_item(task, emergency_category)
			has_tasks = true
	
	# Add regular VISIBLE tasks only
	var visible_tasks = GameManager.task_manager.get_visible_tasks()
	if visible_tasks.size() > 0:
		var tasks_category = create_item(root_item)
		tasks_category.set_text(0, "Daily Tasks")
		tasks_category.set_custom_font_size(0, 14)
		
		for task in visible_tasks:
			if not task.is_emergency:
				_add_task_item(task, tasks_category)
				has_tasks = true
	
	DebugLogger.debug(module_name, "Tree rebuilt with " + str(task_items.size()) + " visible tasks")


func _add_task_item(task: BaseTask, parent: TreeItem) -> void:
	var item = create_item(parent)
	task_items[task.task_id] = item
	
	# Update the item
	_update_task_item(task, item)

func _update_task_item(task: BaseTask, item: TreeItem) -> void:
	# Build task text
	var text = task.task_name
	
	# Add timer for emergency tasks
	if task.is_emergency and show_emergency_timer and task.time_remaining > 0:
		text += " [" + str(int(task.time_remaining)) + "s]"
	
	item.set_text(0, text)
	
	# Add description as tooltip or second column
	if show_task_descriptions and task.task_description:
		item.set_tooltip_text(0, task.task_description)
	
	# Set icon based on state
	if task.is_completed and completed_icon:
		item.set_icon(0, completed_icon)
	elif task.is_emergency and emergency_icon:
		item.set_icon(0, emergency_icon)
	elif not task.is_available and locked_icon:
		item.set_icon(0, locked_icon)
	elif task_icon:
		item.set_icon(0, task_icon)
	
	# Set color based on state
	if task.is_completed:
		item.set_custom_color(0, completed_color)
	elif task.is_emergency:
		item.set_custom_color(0, emergency_color)
	elif not task.is_available:
		item.set_custom_color(0, unavailable_color)
	else:
		item.set_custom_color(0, available_color)
	
	# Make unavailable tasks unselectable
	item.set_selectable(0, task.is_available and not task.is_completed)

func _process(_delta: float) -> void:
	# Update emergency task timers
	if GameManager and GameManager.task_manager:
		var emergency_tasks = GameManager.task_manager.get_active_emergency_tasks()
		for task in emergency_tasks:
			if task_items.has(task.task_id):
				_update_task_item(task, task_items[task.task_id])

func _check_visibility() -> void:
	if not GameManager or not GameManager.task_manager:
		set_should_show(false)
		return
	
	var should_show = true
	
	# Check if we should auto-hide when empty
	if auto_hide_when_empty and not GameManager.task_manager.has_active_tasks():
		should_show = false
		DebugLogger.debug(module_name, "Auto-hiding: no active tasks")
	
	# Check if we should auto-hide when all complete
	elif auto_hide_when_complete and GameManager.task_manager.are_all_tasks_completed():
		should_show = false
		DebugLogger.debug(module_name, "Auto-hiding: all tasks completed")
	
	set_should_show(should_show)

func set_should_show(should_show: bool) -> void:
	if visible != should_show:
		visible = should_show
		visibility_state_changed.emit(should_show)
		DebugLogger.debug(module_name, "Visibility changed to: " + str(should_show))

# Public method to manually show/hide
func show_tasks() -> void:
	visible = true
	_rebuild_tree()
	visibility_state_changed.emit(true)

func hide_tasks() -> void:
	visible = false
	visibility_state_changed.emit(false)

# Signal handlers
func _on_task_assigned(_task_id: String) -> void:
	_rebuild_tree()
	_check_visibility()

func _on_task_completed(task_id: String) -> void:
	# Just update the specific taskw
	if GameManager and GameManager.task_manager:
		var task = GameManager.task_manager.get_task(task_id)
		if task and task_items.has(task_id):
			_update_task_item(task, task_items[task_id])
	_check_visibility()

func _on_emergency_task_triggered(_task_id: String) -> void:
	_rebuild_tree()
	_check_visibility()

func _on_daily_tasks_completed() -> void:
	# Could show a completion message or effect
	DebugLogger.info(module_name, "All daily tasks completed!")
	_check_visibility()

func _on_day_started(_day_number: int) -> void:
	_rebuild_tree()
	_check_visibility()

func _on_day_reset() -> void:
	DebugLogger.info(module_name, "Day reset signal received - clearing task tree")
	
	# Clear the tree immediately
	self.clear()
	task_items.clear()
	
	# Hide the tree
	hide_tasks()
	
	# Start timer to rebuild tree after delay
	rebuild_timer.start(rebuild_delay_after_reset)
	DebugLogger.debug(module_name, "Will rebuild tree in " + str(rebuild_delay_after_reset) + " seconds")

func _on_rebuild_timer_timeout() -> void:
	DebugLogger.debug(module_name, "Rebuild timer expired - rebuilding tree")
	_rebuild_tree()
	_check_visibility()

# Public method to get selected task
func get_selected_task() -> BaseTask:
	var selected = get_selected()
	if not selected:
		return null
	
	# Find which task this item represents
	for task_id in task_items:
		if task_items[task_id] == selected:
			if GameManager and GameManager.task_manager:
				return GameManager.task_manager.get_task(task_id)
	
	return null
