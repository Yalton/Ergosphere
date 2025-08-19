extends AudioStreamPlayer3D
class_name MonsterFootstepPlayer

## The footstep sounds to randomly play from
@export var footstep_sounds: AudioStreamRandomizer
## Volume adjustment for footsteps
@export var footstep_volume: float = 0.0
## Optional pitch variation (1.0 = no variation)
@export var pitch_variation: float = 0.1

func _ready():
	# Set up the audio player
	bus = "SFX"  # Assuming you want it on SFX bus
	volume_db = footstep_volume
	
	if not footstep_sounds:
		push_warning("MonsterFootstepPlayer: No footstep sounds assigned")

func play_footstep():
	"""Called from animation to play a footstep sound"""
	if not footstep_sounds:
		return
	
	# Set the stream and play
	stream = footstep_sounds
	
	# Apply random pitch variation if desired
	if pitch_variation > 0:
		pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	
	play()
