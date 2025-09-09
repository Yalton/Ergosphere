# ModuleDebugConfig.gd
class_name ModuleDebugConfig
extends Resource

# Module identification
@export var module_name: String = ""

# Debug settings
@export var enabled: bool = false

func _init():
	# Default initialization
	resource_name = "ModuleDebugConfig"
