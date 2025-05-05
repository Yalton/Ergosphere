# DebugManagerUI.gd
@tool
extends Control

# Module list and selection
@onready var module_list = $VBoxContainer/HSplitContainer/PanelContainer/ScrollContainer/ModuleList
@onready var global_toggle = $VBoxContainer/GlobalSettings/GlobalToggle
@onready var enable_all_button = $VBoxContainer/ModuleControls/EnableAllButton
@onready var disable_all_button = $VBoxContainer/ModuleControls/DisableAllButton
@onready var refresh_button = $VBoxContainer/ModuleControls/RefreshButton
@onready var delete_all_button = $VBoxContainer/GlobalSettings/DeleteModuleFiles
@onready var status_label = $VBoxContainer/StatusBar/StatusLabel

# Current state
var modules_data: Dictionary = {}

func _ready():
	# Connect signals
	global_toggle.toggled.connect(_on_global_toggle)
	enable_all_button.pressed.connect(_on_enable_all_pressed)
	disable_all_button.pressed.connect(_on_disable_all_pressed)
	refresh_button.pressed.connect(_load_modules)
	delete_all_button.pressed.connect(_on_delete_all_pressed)
	
	# Load modules from config directory
	_load_modules()

# Improved _load_modules function with sorting
func _load_modules():
	# Clear existing modules from the list
	for child in module_list.get_children():
		child.queue_free()
	
	modules_data.clear()
	
	# Get global debug setting
	var global_enabled = true
	if Engine.has_singleton("DebugLogger"):
		global_enabled = DebugLogger.debug_enabled
	
	global_toggle.button_pressed = global_enabled
	
	# Path for module configs
	var config_path = "user://debug_modules/"
	var modules_loaded = 0
	
	# Check if directory exists
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(config_path):
		var err = dir.make_dir(config_path)
		status_label.text = "Created debug modules directory"
		return
	
	# Open the directory and list files
	dir = DirAccess.open(config_path)
	if dir:
		# Create a sorted list of modules
		var module_names = []
		
		# Important: reset the list before starting
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		# First pass: collect all module names
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var module_name = file_name.get_basename()
				var config_file = config_path + file_name
				
				# Load the resource
				var config = ResourceLoader.load(config_file)
				if config and config is ModuleDebugConfig:
					modules_data[module_name] = config
					module_names.append(module_name)
					
			# Important: get the next file
			file_name = dir.get_next()
		
		# Also get active modules from DebugLogger
		if Engine.has_singleton("DebugLogger"):
			for module_name in DebugLogger.registered_modules.keys():
				if not modules_data.has(module_name):
					var is_enabled = DebugLogger.registered_modules[module_name]
					
					# Create config for this module
					var config = ModuleDebugConfig.new()
					config.module_name = module_name
					config.enabled = is_enabled
					
					# Only save the config if file writing is enabled
					if Engine.has_singleton("DebugLogger") and not DebugLogger.disable_file_writing:
						# Save to file
						var save_path = config_path + module_name + ".tres"
						var err = ResourceSaver.save(config, save_path)
					
					modules_data[module_name] = config
					if not module_names.has(module_name):
						module_names.append(module_name)
		
		# Sort the module names alphabetically
		module_names.sort()
		
		# Second pass: create checkboxes in sorted order
		for module_name in module_names:
			var config = modules_data[module_name]
			
			# Create a checkbox for this module
			var checkbox = CheckBox.new()
			checkbox.text = module_name
			checkbox.button_pressed = config.enabled
			checkbox.toggled.connect(_on_module_toggled.bind(module_name))
			
			module_list.add_child(checkbox)
			modules_loaded += 1
	
	status_label.text = "Loaded " + str(modules_loaded) + " modules"

func _on_module_toggled(enabled: bool, module_name: String):
	if not modules_data.has(module_name):
		return
	
	modules_data[module_name].enabled = enabled
	_save_module_config(module_name)
	
	# Update DebugLogger if available
	if Engine.has_singleton("DebugLogger") and DebugLogger.registered_modules.has(module_name):
		DebugLogger.set_module_enabled(module_name, enabled)
		status_label.text = "Updated " + module_name + ": " + ("Enabled" if enabled else "Disabled")

func _save_module_config(module_name: String):
	if not modules_data.has(module_name):
		return
	
	# Check if file writing is disabled
	if Engine.has_singleton("DebugLogger") and DebugLogger.disable_file_writing:
		return
		
	var config = modules_data[module_name]
	
	# Save to file
	var config_path = "user://debug_modules/" + module_name + ".tres"
	var err = ResourceSaver.save(config, config_path)
	
	if err != OK:
		status_label.text = "Error saving module config: " + str(err)

func _on_global_toggle(enabled: bool):
	if Engine.has_singleton("DebugLogger"):
		DebugLogger.debug_enabled = enabled
		status_label.text = "Global debug " + ("enabled" if enabled else "disabled")

func _on_enable_all_pressed():
	for child in module_list.get_children():
		if child is CheckBox:
			child.button_pressed = true
	
	status_label.text = "All modules enabled"

func _on_disable_all_pressed():
	for child in module_list.get_children():
		if child is CheckBox:
			child.button_pressed = false
	
	status_label.text = "All modules disabled"

func _on_delete_all_pressed():
	# Confirm deletion
	var confirmation_dialog = ConfirmationDialog.new()
	confirmation_dialog.title = "Delete All Module Files"
	confirmation_dialog.dialog_text = "Are you sure you want to delete all module config files?"
	confirmation_dialog.confirmed.connect(_confirm_delete_all_configs)
	add_child(confirmation_dialog)
	confirmation_dialog.popup_centered()

func _confirm_delete_all_configs():
	# Path for module configs
	var config_path = "user://debug_modules/"
	var files_deleted = 0
	
	# Check if directory exists
	var dir = DirAccess.open(config_path)
	if dir:
		# List all files
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		# Delete all .tres files
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path = config_path + file_name
				var err = dir.remove(full_path)
				if err == OK:
					files_deleted += 1
				
			# Get next file
			file_name = dir.get_next()
	
	status_label.text = "Deleted " + str(files_deleted) + " module config files"
	
	# Refresh module list
	_load_modules()
