# NoteHitParticles.gd
extends GPUParticles2D

# Set the default lifetime to 1 second
@export var auto_destroy_time: float = 1.0

func _ready():
	# Start emitting immediately
	emitting = true
	
	# Create a timer to auto-destroy after emission
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = auto_destroy_time
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	timer.start()
