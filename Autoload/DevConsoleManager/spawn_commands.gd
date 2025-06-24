# SpawnCommands.gd
extends BaseCommandHandler

## Handles item spawning commands using StorageManager registry

## Distance to spawn item away from player
var spawn_distance: float = 2.0
## Height offset multiplier relative to player height  
var height_offset_multiplier: float = 0.5

func _ready() -> void:
	handler_name = "SpawnCommands"
	super._ready()

func register_commands() -> void:
	register_command("spawn_item", _cmd_spawn_item, "Spawn item in front of player. Usage: spawn_item <item_id>", true)
	register_alias("spawn", "spawn_item")

func _cmd_spawn_item(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: spawn_item <item_id>")
		_list_available_items()
		return
	
	var item_id = args[0]
	var storage_manager = _find_storage_manager()
	
	if not storage_manager:
		output_error("Storage manager not found")
		DebugLogger.error(module_name, "Storage manager not available")
		return
	
	var item = storage_manager.get_item_by_id(item_id)
	if not item:
		output_error("Item not found: " + item_id)
		_list_available_items()
		return
	
	var success = _spawn_item(item)
	if success:
		output("Spawned " + item.display_name + " in front of player")
		DebugLogger.info(module_name, "Successfully spawned item: " + item_id)
	else:
		output_error("Failed to spawn item: " + item_id)
		DebugLogger.error(module_name, "Failed to spawn item: " + item_id)

func _spawn_item(item: ShopItem) -> bool:
	var player = CommonUtils.get_player()
	if not player:
		DebugLogger.error(module_name, "Player not found")
		return false
	
	var spawn_pos = _calculate_spawn_position(player)
	
	if not ResourceLoader.exists(item.scene_path):
		DebugLogger.error(module_name, "Scene file not found: " + item.scene_path)
		return false
	
	var item_scene = load(item.scene_path)
	if not item_scene:
		DebugLogger.error(module_name, "Failed to load scene: " + item.scene_path)
		return false
	
	var item_instance = item_scene.instantiate()
	if not item_instance:
		DebugLogger.error(module_name, "Failed to instantiate scene: " + item.scene_path)
		return false
	
	var props_group = _find_props_group()
	if props_group:
		props_group.add_child(item_instance)
	else:
		get_tree().current_scene.add_child(item_instance)
	
	item_instance.global_position = spawn_pos
	
	DebugLogger.debug(module_name, "Item spawned at position: " + str(spawn_pos))
	return true

func _calculate_spawn_position(player: Node3D) -> Vector3:
	var player_pos = player.global_position
	var player_forward = -player.global_transform.basis.z
	
	var height_offset = 0.0
	if player is CharacterBody3D and player.collision_shape:
		var shape = player.collision_shape.shape
		if shape is CapsuleShape3D:
			height_offset = shape.height * height_offset_multiplier
		elif shape is BoxShape3D:
			height_offset = shape.size.y * height_offset_multiplier
		else:
			height_offset = 1.0
	else:
		height_offset = 1.0
	
	var spawn_pos = player_pos + (player_forward * spawn_distance)
	spawn_pos.y += height_offset
	
	DebugLogger.debug(module_name, "Spawn position calculated: " + str(spawn_pos))
	return spawn_pos

func _find_storage_manager() -> StorageManager:
	var found = get_tree().get_first_node_in_group("storage_manager")
	if found and found is StorageManager:
		return found
	
	var nodes = get_tree().get_nodes_in_group("autoload")
	for node in nodes:
		if node is StorageManager:
			return node
	
	found = _recursive_find_storage_manager(get_tree().current_scene)
	if found:
		return found
	
	return null

func _recursive_find_storage_manager(node: Node) -> StorageManager:
	if node is StorageManager:
		return node
	
	for child in node.get_children():
		var result = _recursive_find_storage_manager(child)
		if result:
			return result
	
	return null

func _find_props_group() -> Node:
	var prop_names = ["Props", "items", "objects", "spawned_items"]
	
	for name in prop_names:
		var found = get_tree().get_first_node_in_group(name.to_lower())
		if found:
			return found
	
	for name in prop_names:
		var found = get_tree().current_scene.find_child(name, true)
		if found:
			return found
	
	return null

func _list_available_items() -> void:
	var storage_manager = _find_storage_manager()
	if not storage_manager:
		return
	
	var items = storage_manager.get_all_items()
	if items.is_empty():
		output_system("No items available in storage registry")
		return
	
	output_system("Available items:")
	for item in items:
		output("  " + item.item_id + " - " + item.display_name)
