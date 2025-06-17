# SpookyAmbienceHandler.gd
extends EventHandler
class_name SpookyAmbienceHandler

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
	module_name = "SpookyAmbienceHandler"
	super._ready()
	
	
	# Define which events this handler processes
	handled_event_ids = ["subtle_horror", "jarring_horror", "confusing_horror"]
	
	DebugLogger.debug(module_name, "SpookyAmbienceHandler ready")

func _on_execute(event_data: EventData, state_manager: StateManager) -> void:
	## Handle spooky ambience event execution
	DebugLogger.info(module_name, "Executing horror event: %s" % event_data.event_id)
	
	match event_data.event_id:
		"subtle_horror":
			_handle_subtle_horror(event_data, state_manager)
		"jarring_horror":
			_handle_jarring_horror(event_data, state_manager)
		"confusing_horror":
			_handle_confusing_horror(event_data, state_manager)

func _on_complete(event_data: EventData, state_manager: StateManager) -> void:
	## Handle horror event completion (sounds fade out naturally)
	DebugLogger.info(module_name, "Completing horror event: %s" % event_data.event_id)
	
	# Horror events complete naturally when sound ends
	# Could add fade-out logic here if needed

func _handle_subtle_horror(event_data: EventData, state_manager: StateManager) -> void:
	## Handle subtle horror - quiet atmospheric sounds
	DebugLogger.debug(module_name, "Playing subtle horror sound")
	
	_play_from_sound_pool(subtle_horror_sounds, "subtle horror")


func _handle_jarring_horror(event_data: EventData, state_manager: StateManager) -> void:
	## Handle jarring horror - sudden loud sounds
	DebugLogger.debug(module_name, "Playing jarring horror sound")
	
	_play_from_sound_pool(jarring_horror_sounds, "jarring horror")


func _handle_confusing_horror(event_data: EventData, state_manager: StateManager) -> void:
	## Handle confusing horror - weird disorienting sounds
	DebugLogger.debug(module_name, "Playing confusing horror sound")
	
	_play_from_sound_pool(confusing_horror_sounds, "confusing horror")
	

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
