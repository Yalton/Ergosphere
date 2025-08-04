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
	# Define which events this handler processes
	handled_event_ids = ["subtle_horror", "jarring_horror", "confusing_horror", "spooky_ambience"]

func _can_execute_internal() -> Dictionary:
	# Check which sound pool we need based on event ID
	match event_data.id:
		"subtle_horror":
			if subtle_horror_sounds.is_empty():
				return {"success": false, "message": "No subtle horror sounds configured"}
		"jarring_horror":
			if jarring_horror_sounds.is_empty():
				return {"success": false, "message": "No jarring horror sounds configured"}
		"confusing_horror":
			if confusing_horror_sounds.is_empty():
				return {"success": false, "message": "No confusing horror sounds configured"}
		"spooky_ambience":
			# Generic needs at least one pool
			if subtle_horror_sounds.is_empty() and jarring_horror_sounds.is_empty() and confusing_horror_sounds.is_empty():
				return {"success": false, "message": "No horror sounds configured in any category"}
	
	return {"success": true, "message": "OK"}

func _execute_internal() -> Dictionary:
	# Handle based on event ID
	match event_data.id:
		"subtle_horror":
			return _handle_subtle_horror()
		"jarring_horror":
			return _handle_jarring_horror()
		"confusing_horror":
			return _handle_confusing_horror()
		"spooky_ambience":
			# Generic spooky ambience - pick from any pool
			return _handle_generic_horror()
		_:
			return {"success": false, "message": "Unknown event ID: " + event_data.id}

func end() -> void:
	# Horror events complete naturally when sound ends
	# Call base implementation
	super.end()

func _handle_subtle_horror() -> Dictionary:
	## Handle subtle horror - quiet atmospheric sounds
	return _play_from_sound_pool(subtle_horror_sounds, "subtle horror")

func _handle_jarring_horror() -> Dictionary:
	## Handle jarring horror - sudden loud sounds
	return _play_from_sound_pool(jarring_horror_sounds, "jarring horror")

func _handle_confusing_horror() -> Dictionary:
	## Handle confusing horror - weird disorienting sounds
	return _play_from_sound_pool(confusing_horror_sounds, "confusing horror")

func _handle_generic_horror() -> Dictionary:
	## Handle generic horror - pick from any available pool
	var available_pools = []
	if not subtle_horror_sounds.is_empty():
		available_pools.append(subtle_horror_sounds)
	if not jarring_horror_sounds.is_empty():
		available_pools.append(jarring_horror_sounds)
	if not confusing_horror_sounds.is_empty():
		available_pools.append(confusing_horror_sounds)
	
	if available_pools.is_empty():
		return {"success": false, "message": "No horror sounds configured in any pool"}
	
	var selected_pool = available_pools[randi() % available_pools.size()]
	return _play_from_sound_pool(selected_pool, "generic horror")

func _play_from_sound_pool(sound_pool: Array[AudioStream], pool_name: String) -> Dictionary:
	## Play a random sound from the specified pool
	if sound_pool.is_empty():
		return {"success": false, "message": "No sounds configured for " + pool_name + " pool"}
	
	var random_sound = sound_pool[randi() % sound_pool.size()]
	return _play_horror_sound(random_sound, pool_name)

func _play_horror_sound(sound: AudioStream, category: String) -> Dictionary:
	## Play a specific horror sound using the Audio singleton
	if not sound:
		return {"success": false, "message": "Attempted to play null sound from " + category + " category"}
	
	if not Audio:
		return {"success": false, "message": "Audio singleton not found"}
	
	# Play sound using Audio singleton
	Audio.play_sound(sound, true, 1.0, horror_volume, audio_bus)
	
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
	
	return {"success": true, "message": "OK"}
