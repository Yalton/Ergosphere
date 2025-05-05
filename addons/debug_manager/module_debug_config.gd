# ModuleDebugConfig.gd
class_name ModuleDebugConfig
extends Resource

# Module identification
@export var module_name: String = ""

# Debug settings
@export var enabled: bool = true

func _init():
	# Default initialization
	resource_name = "ModuleDebugConfig"
