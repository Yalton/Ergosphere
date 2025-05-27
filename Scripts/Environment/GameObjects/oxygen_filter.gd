extends BaseSnappable
class_name OxygenFilter

signal filter_failed
signal filter_fixed


@export_group("Components")
@export var air_filter_mesh: MeshInstance3D
@export var broken_light: OmniLight3D
@export var fixed_light: OmniLight3D
@export var animation_player: AnimationPlayer
@export var oxygen_fan_audio: AudioStreamPlayer3D
@export var oxygen_bubbles_audio: AudioStreamPlayer3D  # This should be the RandomAudioStream3D

@export_group("Settings")
@export var fix_animation_name: String = "load_air_filter"

# Internal state
var is_operational: bool = true
var broken_light_tween: Tween
var fixed_light_tween: Tween

func _ready() -> void:
	super._ready()
	module_name = "OxygenFilter"
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	module_name = "OxygenFilter_" + name
	
	# Add to oxygen_filters group for event system to find us
	add_to_group("oxygen_filters")
	
	# Set display name if not already set
	if display_name.is_empty():
		display_name = "Oxygen Filter"
	
	# Initialize in operational state
	set_operational_state(true)
	
	DebugLogger.debug(module_name, "Oxygen filter initialized")

func set_operational_state(operational: bool) -> void:
	is_operational = operational
	can_snap = not operational  # Can only snap when broken
	
	if is_operational:
		# Show air filter
		if air_filter_mesh:
			air_filter_mesh.visible = true
		
		# Start fan audio loop
		if oxygen_fan_audio and not oxygen_fan_audio.playing:
			oxygen_fan_audio.play()
		
		# Resume bubble audio
		if oxygen_bubbles_audio and oxygen_bubbles_audio.has_method("resume_audio"):
			oxygen_bubbles_audio.resume_audio()
		
		# Stop light flashing
		_stop_light_flashing()
		
		DebugLogger.debug(module_name, "Set to operational state")
	else:
		# Hide air filter (it's broken/missing)
		if air_filter_mesh:
			air_filter_mesh.visible = false
		
		# Stop fan audio
		if oxygen_fan_audio:
			oxygen_fan_audio.stop()
		
		# Pause bubble audio
		if oxygen_bubbles_audio and oxygen_bubbles_audio.has_method("pause_audio"):
			oxygen_bubbles_audio.pause_audio()
		
		# Start flashing broken light
		_start_broken_light_flashing()
		
		DebugLogger.debug(module_name, "Set to broken state")

func trigger_failure() -> void:
	if not is_operational:
		DebugLogger.warning(module_name, "Filter already broken")
		return
	
	DebugLogger.info(module_name, "Filter failure triggered")
	set_operational_state(false)
	filter_failed.emit()

func _on_object_snapped(object_name: String, object_node: Node3D) -> void:
	if not is_operational:
		DebugLogger.debug(module_name, "Filter replacement started with: " + object_name)
		_start_repair_sequence()

func _start_repair_sequence() -> void:
	# Play repair animation
	if animation_player and animation_player.has_animation(fix_animation_name):
		animation_player.play(fix_animation_name)
		
		# Wait for animation to finish
		if not animation_player.is_connected("animation_finished", _on_repair_animation_finished):
			animation_player.animation_finished.connect(_on_repair_animation_finished)
	else:
		# No animation, complete repair immediately
		_complete_repair()

func _on_repair_animation_finished(anim_name: String) -> void:
	if anim_name == fix_animation_name:
		_complete_repair()

func _complete_repair() -> void:
	# Stop broken light flashing
	_stop_light_flashing()
	
	# Flash fixed light briefly
	_flash_fixed_light()
	
	# Set back to operational
	set_operational_state(true)
	
	# Inform event system
	filter_fixed.emit()
	
	# Inform GameManager if available
	if GameManager and GameManager.state_manager:
		GameManager.state_manager.set_state("oxygen_system_operational", true)
	
	DebugLogger.info(module_name, "Filter repair completed")

func _start_broken_light_flashing() -> void:
	if not broken_light:
		return
	
	_stop_light_flashing()  # Clean up any existing tweens
	
	broken_light_tween = create_tween()
	broken_light_tween.set_loops()
	broken_light_tween.tween_property(broken_light, "visible", true, 0.0)
	broken_light_tween.tween_interval(0.5)
	broken_light_tween.tween_property(broken_light, "visible", false, 0.0)
	broken_light_tween.tween_interval(0.5)

func _flash_fixed_light() -> void:
	if not fixed_light:
		return
	
	# Brief orange flash
	fixed_light_tween = create_tween()
	fixed_light_tween.tween_property(fixed_light, "visible", true, 0.0)
	fixed_light_tween.tween_interval(0.2)
	fixed_light_tween.tween_property(fixed_light, "visible", false, 0.0)
	fixed_light_tween.tween_interval(0.2)
	fixed_light_tween.tween_property(fixed_light, "visible", true, 0.0)
	fixed_light_tween.tween_interval(0.2)
	fixed_light_tween.tween_property(fixed_light, "visible", false, 0.0)

func _stop_light_flashing() -> void:
	if broken_light_tween and broken_light_tween.is_valid():
		broken_light_tween.kill()
	
	if fixed_light_tween and fixed_light_tween.is_valid():
		fixed_light_tween.kill()
	
	# Ensure lights are in correct state
	if broken_light:
		broken_light.visible = false
	if fixed_light:
		fixed_light.visible = false

# Public method for event system to check if this filter can fail
func can_fail() -> bool:
	return is_operational
