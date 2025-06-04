# OptionsUIControl.gd
extends Control
class_name OptionsUIControl

signal back_pressed

@export var enable_debug: bool = false
var module_name: String = "OptionsUIControl"

# Audio sliders
@export var master_volume_slider: HSlider
@export var music_volume_slider: HSlider
@export var sfx_volume_slider: HSlider

# Graphics checkbox
@export var high_quality_checkbox: CheckBox

# Video settings
@export var vsync_checkbox: CheckBox
@export var quality_lighting_checkbox: CheckBox
@export var fullscreen_menu_button: MenuButton
@export var resolution_menu_button: MenuButton

# Back button
@export var back_button: Button

func _ready() -> void:
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	
	# Connect audio sliders
	if master_volume_slider:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
		DebugLogger.debug(module_name, "Connected master volume slider")
	
	if music_volume_slider:
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
		DebugLogger.debug(module_name, "Connected music volume slider")
	
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
		DebugLogger.debug(module_name, "Connected SFX volume slider")
	
	# Connect graphics checkbox
	if high_quality_checkbox:
		high_quality_checkbox.toggled.connect(_on_quality_toggled)
		DebugLogger.debug(module_name, "Connected high quality checkbox")
	
	# Connect video settings
	if vsync_checkbox:
		vsync_checkbox.toggled.connect(_on_vsync_toggled)
		DebugLogger.debug(module_name, "Connected vsync checkbox")
	
	if quality_lighting_checkbox:
		quality_lighting_checkbox.toggled.connect(_on_quality_lighting_toggled)
		DebugLogger.debug(module_name, "Connected quality lighting checkbox")
	
	# Setup MenuButtons (since items are already in editor)
	if fullscreen_menu_button:
		var popup = fullscreen_menu_button.get_popup()
		if not popup.is_connected("id_pressed", _on_fullscreen_selected):
			popup.id_pressed.connect(_on_fullscreen_selected)
		DebugLogger.debug(module_name, "Connected fullscreen menu button with " + str(popup.item_count) + " items")
	
	if resolution_menu_button:
		var popup = resolution_menu_button.get_popup()
		if not popup.is_connected("id_pressed", _on_resolution_selected):
			popup.id_pressed.connect(_on_resolution_selected)
		DebugLogger.debug(module_name, "Connected resolution menu button with " + str(popup.item_count) + " items")
	
	# Connect back button
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
		DebugLogger.debug(module_name, "Connected back button")
	
	# Load settings on initialization
	refresh_settings()
	
	DebugLogger.info(module_name, "OptionsUIControl initialized")

func refresh_settings() -> void:
	DebugLogger.debug(module_name, "Refreshing all settings from config")
	
	# Load audio settings
	if master_volume_slider:
		master_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(SettingsManager.MASTER_BUS)) * 100
		DebugLogger.debug(module_name, "Master volume: " + str(master_volume_slider.value))
	
	if music_volume_slider:
		music_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(SettingsManager.MUSIC_BUS)) * 100
		DebugLogger.debug(module_name, "Music volume: " + str(music_volume_slider.value))
	
	if sfx_volume_slider:
		sfx_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(SettingsManager.SFX_BUS)) * 100
		DebugLogger.debug(module_name, "SFX volume: " + str(sfx_volume_slider.value))
	
	# Load graphics and video settings from config
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		# Graphics
		if high_quality_checkbox:
			high_quality_checkbox.button_pressed = config.get_value("graphics", "high_quality", true)
			DebugLogger.debug(module_name, "High quality: " + str(high_quality_checkbox.button_pressed))
		
		# Video settings
		if vsync_checkbox:
			vsync_checkbox.button_pressed = SettingsManager.get_vsync()
			DebugLogger.debug(module_name, "VSync: " + str(vsync_checkbox.button_pressed))
		
		if quality_lighting_checkbox:
			quality_lighting_checkbox.button_pressed = SettingsManager.get_quality_lighting()
			DebugLogger.debug(module_name, "Quality lighting: " + str(quality_lighting_checkbox.button_pressed))
		
		# Fullscreen mode
		if fullscreen_menu_button:
			var mode = SettingsManager.get_fullscreen_mode()
			var popup = fullscreen_menu_button.get_popup()
			if mode < popup.item_count:
				fullscreen_menu_button.text = popup.get_item_text(mode)
				DebugLogger.debug(module_name, "Fullscreen mode: " + fullscreen_menu_button.text)
		
		# Resolution
		if resolution_menu_button:
			var current_res = SettingsManager.get_current_resolution()
			var index = SettingsManager.get_resolution_index(current_res)
			var popup = resolution_menu_button.get_popup()
			if index >= 0 and index < popup.item_count:
				resolution_menu_button.text = popup.get_item_text(index)
				DebugLogger.debug(module_name, "Resolution: " + resolution_menu_button.text)
			else:
				# If current resolution not in list, show it anyway
				resolution_menu_button.text = str(current_res.x) + "x" + str(current_res.y)
				DebugLogger.debug(module_name, "Resolution (custom): " + resolution_menu_button.text)
	else:
		DebugLogger.warning(module_name, "No settings file found, using defaults")
		_apply_default_settings()

func _apply_default_settings() -> void:
	if high_quality_checkbox:
		high_quality_checkbox.button_pressed = true
	if vsync_checkbox:
		vsync_checkbox.button_pressed = true
	if quality_lighting_checkbox:
		quality_lighting_checkbox.button_pressed = true
	if fullscreen_menu_button:
		fullscreen_menu_button.text = "Windowed"
	if resolution_menu_button:
		resolution_menu_button.text = "1920x1080"

func save_current_settings() -> void:
	DebugLogger.debug(module_name, "Saving all current settings")
	
	var config = ConfigFile.new()
	# Load existing to preserve other settings
	var err = config.load("user://settings.cfg")
	
	# Save audio
	if master_volume_slider:
		config.set_value("audio", "master_volume", master_volume_slider.value)
	if music_volume_slider:
		config.set_value("audio", "music_volume", music_volume_slider.value)
	if sfx_volume_slider:
		config.set_value("audio", "sfx_volume", sfx_volume_slider.value)
	
	# Save graphics
	if high_quality_checkbox:
		config.set_value("graphics", "high_quality", high_quality_checkbox.button_pressed)
	
	# Save video
	if vsync_checkbox:
		config.set_value("video", "vsync", vsync_checkbox.button_pressed)
	if quality_lighting_checkbox:
		config.set_value("video", "quality_lighting", quality_lighting_checkbox.button_pressed)
	
	# Save fullscreen mode by finding which ID matches current text
	if fullscreen_menu_button:
		var popup = fullscreen_menu_button.get_popup()
		for i in range(popup.item_count):
			if popup.get_item_text(i) == fullscreen_menu_button.text:
				config.set_value("video", "fullscreen_mode", i)
				DebugLogger.debug(module_name, "Saving fullscreen mode: " + str(i))
				break
	
	# Save resolution
	if resolution_menu_button:
		var popup = resolution_menu_button.get_popup()
		for i in range(popup.item_count):
			if popup.get_item_text(i) == resolution_menu_button.text:
				if i < SettingsManager.resolutions.size():
					config.set_value("video", "resolution", SettingsManager.resolutions[i])
					DebugLogger.debug(module_name, "Saving resolution: " + str(SettingsManager.resolutions[i]))
				break
	
	# Save to file
	err = config.save("user://settings.cfg")
	if err == OK:
		DebugLogger.info(module_name, "Settings saved successfully")
	else:
		DebugLogger.error(module_name, "Error saving settings: " + str(err))

# Audio handlers
func _on_master_volume_changed(value: float) -> void:
	DebugLogger.debug(module_name, "Master volume changed to: " + str(value))
	AudioServer.set_bus_volume_db(SettingsManager.MASTER_BUS, linear_to_db(value / 100))
	save_current_settings()

func _on_music_volume_changed(value: float) -> void:
	DebugLogger.debug(module_name, "Music volume changed to: " + str(value))
	AudioServer.set_bus_volume_db(SettingsManager.MUSIC_BUS, linear_to_db(value / 100))
	save_current_settings()

func _on_sfx_volume_changed(value: float) -> void:
	DebugLogger.debug(module_name, "SFX volume changed to: " + str(value))
	AudioServer.set_bus_volume_db(SettingsManager.SFX_BUS, linear_to_db(value / 100))
	save_current_settings()

# Graphics handler
func _on_quality_toggled(button_pressed: bool) -> void:
	DebugLogger.debug(module_name, "High quality toggled to: " + str(button_pressed))
	SettingsManager.apply_quality_settings(button_pressed)
	save_current_settings()

# Video handlers
func _on_vsync_toggled(button_pressed: bool) -> void:
	DebugLogger.debug(module_name, "VSync toggled to: " + str(button_pressed))
	SettingsManager.set_vsync(button_pressed)
	save_current_settings()

func _on_quality_lighting_toggled(button_pressed: bool) -> void:
	DebugLogger.debug(module_name, "Quality lighting toggled to: " + str(button_pressed))
	SettingsManager.set_quality_lighting(button_pressed)
	save_current_settings()

func _on_fullscreen_selected(id: int) -> void:
	var popup = fullscreen_menu_button.get_popup()
	var mode_text = popup.get_item_text(id)
	fullscreen_menu_button.text = mode_text
	DebugLogger.debug(module_name, "Fullscreen mode selected: " + mode_text + " (ID: " + str(id) + ")")
	SettingsManager.set_fullscreen_mode(id)
	save_current_settings()

func _on_resolution_selected(id: int) -> void:
	var popup = resolution_menu_button.get_popup()
	var res_text = popup.get_item_text(id)
	resolution_menu_button.text = res_text
	DebugLogger.debug(module_name, "Resolution selected: " + res_text + " (ID: " + str(id) + ")")
	
	if id < SettingsManager.resolutions.size():
		SettingsManager.set_resolution(SettingsManager.resolutions[id])
	save_current_settings()

func _on_back_button_pressed() -> void:
	DebugLogger.debug(module_name, "Back button pressed")
	back_pressed.emit()
