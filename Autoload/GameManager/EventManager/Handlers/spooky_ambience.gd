# spooky_ambience.gd
extends EventHandler
class_name SpookyAmbienceEvent

## Spooky ambience event handler - plays atmospheric sound effects to build tension

@export_group("Horror Sound Categories")
## Subtle horror sounds - quiet, atmospheric, barely noticeable
@export var subtle_horror_sounds: Array[AudioStream] = []
## Jarring horror sounds - sudden, loud, attention-grabbing
@export var jarring_horror_sounds: Array[AudioStream] = []
## Confusing horror sounds - weird, disorienting, unsettling
@export var confusing_horror_sounds: Array[AudioStream] = []

@export_group("Audio Settings")
## Volume for horror sounds (-80 to 0 dB)
@export var horror_volume: float = 0.0
## Audio bus for horror sounds
@export var audio_bus: String = "SFX"

func _ready() -> void:
	module_name = "SpookyAmbienceEvent"
	super._ready()
	
	
	# Define which events this handler processes
	handled_event_ids = ["subtle_horror", "jarring_horror", "confusing_horror", "spooky_ambience"]
	
	DebugLogger.debug(module_name, "SpookyAmbienceEvent ready")

func can_execute() -> bool:
	# First check base requirements
	if not super.can_execute():
		return false
	
	# Check which sound pool we need based on event ID
	match event_data.id:
		"subtle_horror":
			if subtle_horror_sounds.is_empty():
				DebugLogger.warning(module_name, "No subtle horror sounds configured")
				return false
		"jarring_horror":
			if jarring_horror_sounds.is_empty():
				DebugLogger.warning(module_name, "No jarring horror sounds configured")
				return false
		"confusing_horror":
			if confusing_horror_sounds.is_empty():
				DebugLogger.warning(module_name, "No confusing horror sounds configured")
				return false
	
	return true

func execute() -> bool:
	# Call base implementation
	if not super.execute():
		return false
	
	# Handle based on event ID
	match event_data.id:
		"subtle_horror":
			_handle_subtle_horror()
		"jarring_horror":
			_handle_jarring_horror()
		"confusing_horror":
			_handle_confusing_horror()
		"spooky_ambience":
			# Generic spooky ambience - pick from any pool
			_handle_generic_horror()
	
	return true

func end() -> void:
	# Horror events complete naturally when sound ends
	DebugLogger.info(module_name, "Horror ambience event completed")
	
	# Call base implementation
	super.end()

func _handle_subtle_horror() -> void:
	## Handle subtle horror - quiet atmospheric sounds
	DebugLogger.debug(module_name, "Playing subtle horror sound")
	_play_from_sound_pool(subtle_horror_sounds, "subtle horror")

func _handle_jarring_horror() -> void:
	## Handle jarring horror - sudden loud sounds
	DebugLogger.debug(module_name, "Playing jarring horror sound")
	_play_from_sound_pool(jarring_horror_sounds, "jarring horror")

func _handle_confusing_horror() -> void:
	## Handle confusing horror - weird disorienting sounds
	DebugLogger.debug(module_name, "Playing confusing horror sound")
	_play_from_sound_pool(confusing_horror_sounds, "confusing horror")

func _handle_generic_horror() -> void:
	## Handle generic horror - pick from any available pool
	var available_pools = []
	if not subtle_horror_sounds.is_empty():
		available_pools.append(subtle_horror_sounds)
	if not jarring_horror_sounds.is_empty():
		available_pools.append(jarring_horror_sounds)
	if not confusing_horror_sounds.is_empty():
		available_pools.append(confusing_horror_sounds)
	
	if available_pools.is_empty():
		DebugLogger.warning(module_name, "No horror sounds configured")
		return
	
	var selected_pool = available_pools[randi() % available_pools.size()]
	_play_from_sound_pool(selected_pool, "generic horror")

func _play_from_sound_pool(sound_pool: Array[AudioStream], pool_name: String) -> void:
	## Play a random sound from the specified pool
	if sound_pool.is_empty():
		DebugLogger.warning(module_name, "No sounds configured for %s pool" % pool_name)
		return
	
	var random_sound = sound_pool[randi() % sound_pool.size()]
	_play_horror_sound(random_sound, pool_name)

func _play_horror_sound(sound: AudioStream, category: String) -> void:
	## Play a specific horror sound using the Audio singleton
	if not sound:
		DebugLogger.warning(module_name, "Attempted to play null sound from %s category" % category)
		return
	
	if not Audio:
		DebugLogger.error(module_name, "Audio singleton not found")
		return
	
	# Play sound using Audio singleton
	Audio.play_sound(sound, true, 1.0, horror_volume, audio_bus)
	
	DebugLogger.debug(module_name, "Playing %s sound: %s" % [category, sound.resource_path])
	
	# End event after sound duration (estimate based on stream length)
	if sound.has_method("get_length"):
		var duration = sound.get_length()
		get_tree().create_timer(duration).timeout.connect(func(): 
			if is_active:
				end()
		)
	else:
		# Default duration if we can't get sound length
		get_tree().create_timer(5.0).timeout.connect(func(): 
			if is_active:
				end()
		)
