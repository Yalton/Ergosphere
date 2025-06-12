# CreditsUIControl.gd
extends Control
class_name CreditsUIControl

signal back_pressed

## Credits resource containing all the credit data
@export var credits_resource: CreditsResource

@export var credits_label: RichTextLabel
@export var scroll_container: ScrollContainer
@export var back_button: Button

@export var enable_debug: bool = false
var module_name: String = "CreditsUIControl"

var scroll_timer: Timer

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Create scroll timer
	scroll_timer = Timer.new()
	scroll_timer.wait_time = 0.016  # ~60 FPS
	scroll_timer.timeout.connect(_auto_scroll)
	add_child(scroll_timer)
	
	if credits_resource:
		_populate_credits()

func _populate_credits() -> void:
	if not credits_resource or not credits_label:
		return
	
	# Group entries by category
	var categories = {}
	for entry in credits_resource.credits_entries:
		if not categories.has(entry.category):
			categories[entry.category] = []
		categories[entry.category].append(entry)
	
	# Build credits text
	var text = ""
	for category in categories.keys():
		text += "[b][font_size=24]" + category + "[/font_size][/b]\n\n"
		
		for entry in categories[category]:
			text += entry.role + " - " + entry.name + "\n"
		
		text += "\n"
	
	credits_label.text = text
	
	# Start auto-scroll
	if credits_resource.scroll_speed > 0:
		scroll_timer.start()

func _auto_scroll() -> void:
	if not scroll_container:
		return
	
	var scroll_amount = credits_resource.scroll_speed * scroll_timer.wait_time
	scroll_container.scroll_vertical += int(scroll_amount)

func _input(event: InputEvent) -> void:
	if visible and (event is InputEventMouseButton or event is InputEventKey):
		scroll_timer.stop()

func _on_back_pressed() -> void:
	scroll_timer.stop()
	back_pressed.emit()

func show_credits() -> void:
	show()
	if credits_resource and credits_resource.scroll_speed > 0:
		scroll_timer.start()

func hide_credits() -> void:
	hide()
	scroll_timer.stop()
	if scroll_container:
		scroll_container.scroll_vertical = 0
