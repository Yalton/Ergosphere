# ServerHDDEjector.gd
extends Node3D

@export var download_diegetic_ui: DiegeticUIBase  # Assign your download diegetic UI scene here
@export var eject_animation_player: AnimationPlayer
@export var eject_animation_name: String = "eject_drive"
@export var hdd_prefab: PackedScene  # The hard drive object to spawn
@export var spawn_position: Node3D  # Where to spawn the HDD relative to this object

@export var enable_debug: bool = true
var module_name: String = "ServerEjector"

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Connect to the download diegetic UI's signal
	if download_diegetic_ui:
		if download_diegetic_ui.has_signal("download_completed"):
			download_diegetic_ui.download_completed.connect(_on_download_completed)
			DebugLogger.debug(module_name, "Connected to download diegetic UI signal")
		else:
			DebugLogger.error(module_name, "Download diegetic UI doesn't have download_completed signal!")
	else:
		DebugLogger.error(module_name, "No download diegetic UI assigned!")
	
	if not eject_animation_player:
		DebugLogger.warning(module_name, "No animation player assigned")
	
	if not hdd_prefab:
		DebugLogger.warning(module_name, "No HDD prefab assigned")
	
	if not spawn_position:
		DebugLogger.warning(module_name, "No spawn position assigned - will spawn at server origin")
	
	DebugLogger.debug(module_name, "Server HDD Ejector initialized")

func _on_download_completed() -> void:
	DebugLogger.debug(module_name, "Download completed signal received - ejecting HDD")
	eject_hdd()

func eject_hdd() -> void:
	# Play eject animation if available
	if eject_animation_player and eject_animation_player.has_animation(eject_animation_name):
		eject_animation_player.play(eject_animation_name)
		DebugLogger.debug(module_name, "Playing eject animation: " + eject_animation_name)
		
		# Wait for animation to finish before spawning HDD
		await eject_animation_player.animation_finished
	
	# Spawn the HDD
	spawn_hdd()

func spawn_hdd() -> void:
	if not hdd_prefab:
		DebugLogger.error(module_name, "Cannot spawn HDD - no prefab assigned")
		return
	
	# Instantiate the HDD
	var hdd_instance = hdd_prefab.instantiate()
	
	# Determine spawn position and rotation
	var spawn_transform: Transform3D
	if spawn_position:
		spawn_transform = spawn_position.global_transform
		DebugLogger.debug(module_name, "Spawning HDD at designated position")
	else:
		spawn_transform = global_transform
		DebugLogger.debug(module_name, "Spawning HDD at server position")
	
	# Add to scene
	get_tree().current_scene.add_child(hdd_instance)
	hdd_instance.global_transform = spawn_transform
	
	DebugLogger.debug(module_name, "HDD spawned successfully")

# Manual eject function for testing
func manual_eject() -> void:
	DebugLogger.debug(module_name, "Manual eject triggered")
	eject_hdd()
