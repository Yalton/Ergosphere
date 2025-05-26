# PowerOutageEvent.gd
extends BaseEvent

@export_group("Power Outage Settings")
@export var power_off_sound: AudioStream
@export var power_on_sound: AudioStream
@export var emergency_light_color: Color = Color(0.8, 0.0, 0.0)  # Red
@export var emergency_light_energy: float = 0.3  # Dimmed

@export_group("Emissive Material")
@export var shared_emissive_material: StandardMaterial3D  # The shared material resource
@export var emergency_emission_energy: float = 0.3

# Cached original values
var original_light_states: Array = []
var original_emission_color: Color
var original_emission_energy: float
var audio_player: AudioStreamPlayer

func _ready() -> void:
	super._ready()
	event_name = "power_outage"
	event_description = "Main power has failed, emergency lighting active"
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)
	
	# Cache original emissive values if material is provided
	if shared_emissive_material:
		original_emission_color = shared_emissive_material.emission
		original_emission_energy = shared_emissive_material.emission_energy_multiplier


func _on_start(state_manager: StateManager) -> void:
	# Update state
	state_manager.set_state("power", "off")
	state_manager.set_state("emergency_mode", true)
	
	# Play power off sound
	if power_off_sound and audio_player:
		audio_player.stream = power_off_sound
		audio_player.play()
	
	# Modify all lights in the "lights" group
	_modify_lights(true)
	
	# Modify shared emissive material
	_modify_emissive_material(true)
	
	# Update power lever if we have one
	#if power_lever_path:
	var lever = get_tree().get_first_node_in_group("power_lever")
	if lever and lever.has_method("set_power_state"):
		lever.set_power_state(false)
	
	else: 
		DebugLogger.info(module_name, "Could not find lever")
	
	DebugLogger.info(module_name, "Power outage started - emergency lighting active")

func _on_reverse(state_manager: StateManager) -> void:
	# Update state
	state_manager.set_state("power", "on")
	state_manager.set_state("emergency_mode", false)
	
	# Play power on sound
	if power_on_sound and audio_player:
		audio_player.stream = power_on_sound
		audio_player.play()
	
	# Restore lights
	_restore_lights()
	
	# Restore emissive material
	_modify_emissive_material(false)
	
	# Update power lever
	var lever = get_tree().get_first_node_in_group("power_lever")
	if lever and lever.has_method("set_power_state"):
		lever.set_power_state(true)
	
	DebugLogger.info(module_name, "Power restored - normal lighting active")

func _modify_lights(emergency_mode: bool) -> void:
	# Clear stored states if starting fresh
	if emergency_mode:
		original_light_states.clear()
	
	# Get all lights in the "lights" group
	var lights = get_tree().get_nodes_in_group("lights")
	
	DebugLogger.debug(module_name, "Found " + str(lights.size()) + " lights in group")
	
	for light in lights:
		if light is Light3D:
			if emergency_mode:
				# Store original state
				original_light_states.append({
					"light": light,
					"color": light.light_color,
					"energy": light.light_energy,
					"enabled": light.visible
				})
				
				# Apply emergency lighting
				light.light_color = emergency_light_color
				light.light_energy = emergency_light_energy
			
			DebugLogger.debug(module_name, "Modified light: " + light.name)

func _restore_lights() -> void:
	for state in original_light_states:
		var light = state["light"]
		if is_instance_valid(light):
			light.light_color = state["color"]
			light.light_energy = state["energy"]
			light.visible = state["enabled"]
			
			DebugLogger.debug(module_name, "Restored light: " + light.name)
	
	original_light_states.clear()

func _modify_emissive_material(emergency_mode: bool) -> void:
	if not shared_emissive_material:
		DebugLogger.warning(module_name, "No shared emissive material assigned")
		return
	
	if emergency_mode:
		# Apply emergency emission settings
		shared_emissive_material.emission = emergency_light_color
		shared_emissive_material.emission_energy_multiplier = emergency_emission_energy
		DebugLogger.debug(module_name, "Applied emergency emission to shared material")
	else:
		# Restore original emission settings
		shared_emissive_material.emission = original_emission_color
		shared_emissive_material.emission_energy_multiplier = original_emission_energy
		DebugLogger.debug(module_name, "Restored original emission to shared material")
