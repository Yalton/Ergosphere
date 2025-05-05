# debug_manager_plugin.gd
@tool
extends EditorPlugin

var debug_manager_button = null
var debug_manager_window = null
var debug_manager_instance = null

func _enter_tree():
	# Load debug manager scene
	debug_manager_instance = load("res://addons/debug_manager/debug_manager_ui.tscn").instantiate()
	
	# Add as a dockable control
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, debug_manager_instance)

func _exit_tree():
	# Clean up
	if debug_manager_instance:
		remove_control_from_docks(debug_manager_instance)
		debug_manager_instance.queue_free()

func _on_debug_manager_button_pressed():
	# Toggle visibility
	if debug_manager_window:
		debug_manager_window.visible = !debug_manager_window.visible
		
		# Refresh when shown
		if debug_manager_window.visible and debug_manager_window.has_method("_load_modules"):
			debug_manager_window._load_modules()
