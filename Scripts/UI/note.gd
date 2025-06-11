extends PanelContainer
class_name Note

## The TextureRect child that displays the note image
@onready var texture_rect: TextureRect = $AspectRatioContainer/TextureRect

## Base texture containing all note images (not AtlasTexture)
@export var notes_texture: Texture2D

## Region in atlas for this note's key (0=A, 1=S, 2=D, 3=F)
var key_index: int = 0

# Atlas coordinates for each key (48x48 images)
const KEY_REGIONS = {
	0: Vector2(8, 72),    # A key
	1: Vector2(392, 136), # S key
	2: Vector2(200, 72),  # D key
	3: Vector2(328, 72)   # F key
}

func _ready():
	DebugLogger.register_module("Note")
	
	if texture_rect and notes_texture:
		# Create a new AtlasTexture instance for this note
		var atlas = AtlasTexture.new()
		atlas.atlas = notes_texture
		texture_rect.texture = atlas
		DebugLogger.log_message("Note", "Created new AtlasTexture instance")

func set_key_type(index: int):
	key_index = index
	if not texture_rect or not texture_rect.texture:
		DebugLogger.log_message("Note", "Cannot set key type - texture_rect or texture missing")
		return
	
	if index in KEY_REGIONS:
		var pos = KEY_REGIONS[index]
		var atlas = texture_rect.texture as AtlasTexture
		if atlas:
			# Ensure we're working with our own AtlasTexture instance
			if atlas.atlas != notes_texture:
				# Create a new one if somehow it got replaced
				atlas = AtlasTexture.new()
				atlas.atlas = notes_texture
				texture_rect.texture = atlas
				DebugLogger.log_message("Note", "Recreated AtlasTexture instance")
			
			atlas.region = Rect2(pos.x, pos.y, 48, 48)
			DebugLogger.log_message("Note", "Set key type %d with region: %v" % [index, pos])
		else:
			DebugLogger.log_message("Note", "Failed to cast texture to AtlasTexture")
