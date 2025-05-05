extends Control

enum UIState {
	MAIN_NAV,
	CONTINENT_SELECT,
	CONTINENT_SELECT_WITH_INFO,
	MISSION_SELECT,
	SHOP
}

enum MissionType {
	ARTIFACT_RECOVERY = 0,
	CRYPTID_HUNT = 1
}

signal mission_selected_signal(continent: Continent, map: Map, mission: Mission)
signal continent_selected_signal(continent: Continent)
signal items_purchased_signal(items: Array[InventoryItemPD])
signal purchase_failed

@export var lira_amount: int = 100
@export var faith_amount: int = 80

#region State Machine and Main UI Elements
@onready var state_machine: StateMachineComponent = $StateMachineComponent
@onready var main_nav_windows: Control = $MainNavWindows
@onready var sub_nav_windows: Control = $SubNavWindows
@onready var faith_bar: Control = $MainNavWindows/CenterItems/VBoxContainer/FaithBar
@onready var deploying_location_label: Control = $MainNavWindows/CornerItems/DeployingVBox/MarginContainer/DeployingContainer/MarginContainer/DeployingLocationLabel
#endregion

#region Mission Selection UI
@onready var mission_select_window: Control = $SubNavWindows/MissionSelect
@onready var mission_info_container: Control = $SubNavWindows/MissionSelect/MissionInfoContainer
@onready var mission_info_panel: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel
@onready var select_mission_button: Control = $MainNavWindows/CornerItems/LeftVContainer/SelectMissionContainer_Margin/SelectMissionButton
@onready var location_container: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/Title_Container/LocationContainer
@onready var location_label: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/Title_Container/LocationContainer/LocationLabel
@onready var rewards_difficulty_container: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/RewardsAndDifficultyContainer
@onready var rewards_difficulty_label: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/RewardsAndDifficultyContainer/RewardsAndDifficulty
@onready var mission_info_header: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/Title_Container/HeaderMarginContainer/Header
@onready var mission_info_desc: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/MissionInfoContainer/MissionInfoText
@onready var mission_info_left_button: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/BottomButtons/LeftButton
@onready var mission_info_right_button: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/BottomButtons/RightButton
@onready var mission_info_button_spacer: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/BottomButtons/Space
@onready var mission_back_to_main_button: Control = $SubNavWindows/MissionSelect/BackContainer/BackToMainButton
@onready var mission_close_button: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/Title_Container/CloseButton
#endregion

#region Shop UI
@onready var shop_window: Control = $SubNavWindows/ShopWindow
@onready var shop_button: Control = $MainNavWindows/CornerItems/ShopDatabaseContainer/ShopContainer/ShopButton
@onready var database_button: Control = $CornerItems/ShopDatabaseContainer/DatabaseContainer/DatabaseButton
@onready var cart_total_label: Control = $SubNavWindows/ShopWindow/ShopContainer/VBoxContainer/TabMarginBox/VBoxContainer/ShopBottomNav/PageControls/HBoxContainer/HBoxContainer2/Balance_Label
@onready var purchase_button: Control = $SubNavWindows/ShopWindow/ShopContainer/VBoxContainer/TabMarginBox/VBoxContainer/ShopBottomNav/PageControls/CenterContainer/PurchaseButton
@onready var balance_label: Control = $SubNavWindows/ShopWindow/ShopContainer/MoneyAmountContainer/MoneyLabelContainer/MoneyLabel
@onready var shop_back_to_main: Control = $SubNavWindows/ShopWindow/ShopContainer/TitleContainer/CloseShopButton
#endregion

#region Shop Tabs
@onready var weapons_tab: Control = $SubNavWindows/ShopWindow/ShopContainer/VBoxContainer/TabMarginBox/VBoxContainer/ShopTabContainer/Weapons/Container/Grid
@onready var tools_tab: Control = $SubNavWindows/ShopWindow/ShopContainer/VBoxContainer/TabMarginBox/VBoxContainer/ShopTabContainer/Tools/Container/Grid
@onready var consumable_tab: Control = $SubNavWindows/ShopWindow/ShopContainer/VBoxContainer/TabMarginBox/VBoxContainer/ShopTabContainer/Consumable/Container/Grid
@onready var special_tab: Control = $SubNavWindows/ShopWindow/ShopContainer/VBoxContainer/TabMarginBox/VBoxContainer/ShopTabContainer/Special/Container/Grid
@onready var misc_tab: Control = $SubNavWindows/ShopWindow/ShopContainer/VBoxContainer/TabMarginBox/VBoxContainer/ShopTabContainer/Misc/Container/Grid
#endregion

#region Continent Selection Buttons
@onready var continent_select_container: Control = $SubNavWindows/MissionSelect/ContinentSelectContainer
@onready var asia_button: Control = $SubNavWindows/MissionSelect/ContinentSelectContainer/Asia_Button
@onready var africa_button: Control = $SubNavWindows/MissionSelect/ContinentSelectContainer/Africa_Button
@onready var north_america_button: Control = $SubNavWindows/MissionSelect/ContinentSelectContainer/North_America_Button
@onready var south_america_button: Control = $SubNavWindows/MissionSelect/ContinentSelectContainer/South_America_Button
@onready var antartica_button: Control = $SubNavWindows/MissionSelect/ContinentSelectContainer/Antarctica_Button
@onready var europe_button: Control = $SubNavWindows/MissionSelect/ContinentSelectContainer/Europe_Button
@onready var australia_button: Control = $SubNavWindows/MissionSelect/ContinentSelectContainer/Oceania_Button
#endregion

var selected_continent: Continent
var selected_mission: Mission
var selected_map: Map
var artifact_recovery_mission: Mission
var cryptid_hunt_mission: Mission
var continent_missions: Dictionary = {}
var mission_accepted: bool = false
var cart_total: int = 0
var cart_items: Dictionary = {}

func _ready() -> void:
	# Connect state change signal
	state_machine.connect("state_changed", _on_state_changed)
	
	# Initialize the state machine
	state_machine.add_state("MAIN_NAV", UIState.MAIN_NAV)
	state_machine.add_state("CONTINENT_SELECT", UIState.CONTINENT_SELECT)
	state_machine.add_state("CONTINENT_SELECT_WITH_INFO", UIState.CONTINENT_SELECT_WITH_INFO)
	state_machine.add_state("MISSION_SELECT", UIState.MISSION_SELECT)
	state_machine.add_state("SHOP", UIState.SHOP)
	
	# Set initial state
	state_machine.set_state(UIState.MAIN_NAV)
	
	_on_state_changed(UIState.MAIN_NAV)
	
	faith_bar.value = faith_amount
	
	# Connect button signals
	select_mission_button.pressed.connect(_on_select_mission_pressed)
	mission_back_to_main_button.pressed.connect(_on_mission_back_to_main_button)
	mission_close_button.pressed.connect(_on_mission_close_button)
	shop_back_to_main.pressed.connect(_on_shop_back_to_main)
	shop_button.pressed.connect(_on_shop_button)
	
	purchase_button.pressed.connect(_on_purchase_button_pressed)
	
	mission_info_left_button.pressed.connect(_on_mission_info_left_button_pressed)
	mission_info_right_button.pressed.connect(_on_mission_info_right_button_pressed)
	
	# Connect continent buttons
	# Connect continent buttons
	var continent_buttons : Dictionary = {
		"Asia": asia_button,
		"Africa": africa_button,
		"North America": north_america_button,
		"South America": south_america_button,
		"Antarctica": antartica_button,
		"Europe": europe_button,
		"Oceania": australia_button
	}
	for continent_name in continent_buttons:
		var button = continent_buttons[continent_name]
		button.pressed.connect(_on_continent_button_pressed.bind(continent_name))
	compute_all_continent_missions()

func reset() -> void: 
	selected_continent = null
	selected_mission = null
	selected_map = null
	mission_accepted = false
	continent_missions = {}
	cart_items = {}
	
	update_lira_and_balance()
	clear_cart()
	compute_all_continent_missions()

func _on_purchase_button_pressed() -> void:
	if cart_total > lira_amount:
		emit_signal("purchase_failed")
		flash_red(balance_label)
		flash_red(cart_total_label)
	else:
		lira_amount -= cart_total
		balance_label.text = "₺ " + str(lira_amount)
		var purchased_items: Array[InventoryItemPD] = []
		for item in cart_items:
			for i in range(cart_items[item]):
				purchased_items.append(item)
		
		items_purchased_signal.emit(purchased_items)
		clear_cart()

func update_lira_and_balance(): 
	balance_label.text = "₺ " + str(lira_amount)
	faith_bar.value = faith_amount

func update_cart_total() -> void:
	cart_total = 0
	for item in cart_items:
		cart_total += item.price * cart_items[item]
	
	cart_total_label.text = " ₺ " + str(cart_total)

func clear_cart() -> void:
	cart_items.clear()
	cart_total = 0
	update_cart_total()
	for tab in [weapons_tab, tools_tab, consumable_tab, special_tab, misc_tab]:
		for child in tab.get_children():
			if child.has_method("update_item_count_display"):
				child.des_item_count = 0
				child.update_item_count_display()

func flash_red(label: Control) -> void:
	var tween = create_tween()
	tween.tween_property(label, "modulate", Color.RED, 0.1)
	tween.tween_property(label, "modulate", Color.WHITE, 0.1)
	tween.tween_property(label, "modulate", Color.RED, 0.1)
	tween.tween_property(label, "modulate", Color.WHITE, 0.1)

func compute_all_continent_missions() -> void:
	for continent in Registry.get_all_continents():
		compute_continent_missions(continent)

func compute_continent_missions(continent: Continent) -> void:
	var map = Registry.get_maps_for_continent(continent.Name)[0] # Assuming one map per continent
	var artifact_mission = Registry.get_random_mission_by_type(map, MissionType.ARTIFACT_RECOVERY)
	var cryptid_mission = Registry.get_random_mission_by_type(map, MissionType.CRYPTID_HUNT)
	continent_missions[continent.Name] = {
		"artifact": artifact_mission,
		"cryptid": cryptid_mission
	}
	
func generate_mission_info_text(mission: Mission) -> String:
	var difficulty_text = ""
	var difficulty_color = ""
	
	match mission.Difficulty:
		1:
			difficulty_text = "Easy"
			difficulty_color = "#FFFFFF"  # White
		2:
			difficulty_text = "Medium"
			difficulty_color = "#FFFF00"  # Yellow
		3:
			difficulty_text = "Hard"
			difficulty_color = "#FF0000"  # Red
		4:
			difficulty_text = "Impossible"
			difficulty_color = "#FF0000"  # Red
	
	var difficulty_formatted = ""
	if mission.Difficulty == 4:
		difficulty_formatted = "[pulse freq=1.0 color=#ffffff40 ease=-2.0][color=%s]%s[/color][/pulse]" % [difficulty_color, difficulty_text]
	else:
		difficulty_formatted = "[color=%s]%s[/color]" % [difficulty_color, difficulty_text]
	
	var formatted_text = """[ul]
Difficulty: %s
Payment : [color=#009933]₺ %d[/color]
Faith Restoration: [color=#ffcc00] %d [/color]
[/ul]""" % [difficulty_formatted, mission.LiraReward, mission.FaithReward]
	
	#temp_format = """[center][b] %s [/b][/center] """ % []
	return formatted_text
	
func mission_selected(mission: Mission) -> void:
	if state_machine.get_state() == UIState.MISSION_SELECT:
		accept_mission()
	else:
		print("Mission Selected ", mission.Name)
		selected_mission = mission
		#update_mission_info_display(mission)
		state_machine.set_state(UIState.MISSION_SELECT)
		rewards_difficulty_label.text = generate_mission_info_text(mission)

func accept_mission() -> void:
	# Set the current mission
	# You might want to store this in a global game state or player object
	print("Accepted mission: ", selected_mission.Name)
	mission_accepted = true
	# Lock mission select screen
	select_mission_button.disabled = true
	# Inform other Nodes the player has selected a mission
	mission_selected_signal.emit(selected_continent, selected_map, selected_mission)
	# Go back to main menu
	state_machine.set_state(UIState.MAIN_NAV)

func _on_continent_button_pressed(continent_name: String) -> void:
	selected_continent = Registry.get_continent(continent_name)
	continent_selected_signal.emit(selected_continent)
	continent_selected(selected_continent)

func _on_item_count_changed(item: InventoryItemPD, count: int, price: int) -> void:
	if count > 0:
		cart_items[item] = count
	else:
		cart_items.erase(item)
	
	update_cart_total()
	
func populate_shop_tabs() -> void:
	populate_tab(weapons_tab, "Weapon")
	populate_tab(tools_tab, "Tool")
	populate_tab(consumable_tab, "Consumable")
	populate_tab(special_tab, "Special")
	populate_tab(misc_tab, "Misc")

func populate_tab(tab: Control, category: String) -> void:
	var items = Registry.get_items_by_category(category)
	print("Got Items by category ", category, " item list: ", items)
	var item_display_scene = preload ("res://Prefabs/UI/Shop_Item_Container.tscn")
	
	# Clear existing children
	for child in tab.get_children():
		child.queue_free()
	
	# Populate up to 8 slots
	for i in range(8):
		var item_display = item_display_scene.instantiate()
		tab.add_child(item_display)
		
		if i < items.size():
			#item_display.shop_item = items[i]
			item_display.add_item(items[i])
			item_display.show_full_container()
			item_display.connect("item_count_changed", _on_item_count_changed)

		else:
			item_display.shop_item = null
			item_display.show_empty_container()

func _on_state_changed(new_state : int) -> void:
	match new_state:
		UIState.MAIN_NAV:
			main_nav_windows.show()
			shop_window.hide()
			mission_select_window.hide()
			sub_nav_windows.hide()
			if mission_accepted:
				deploying_location_label.text = selected_map.Name
			else: 
				deploying_location_label.text = "Not Selected"
		UIState.CONTINENT_SELECT:
			main_nav_windows.hide()
			sub_nav_windows.show()
			shop_window.hide()
			mission_select_window.show()
			mission_info_panel.hide()
			#mission_info_container.hide()
		UIState.CONTINENT_SELECT_WITH_INFO:
			mission_info_panel.show()
			mission_info_header.text = """[center] %s [/center] """ % [selected_continent.Name]
			mission_info_desc.text = selected_continent.Description
			mission_info_left_button.show()
			mission_info_left_button.text = "Artifact Recovery"
			mission_info_right_button.show()
			mission_info_right_button.text = "Cryptid Hunt"
			rewards_difficulty_container.hide()
			location_container.hide()
		UIState.MISSION_SELECT:
			mission_info_header.text = """[center] %s [/center] """ % [selected_mission.Name]
			mission_info_desc.text = selected_mission.Objective
			location_label.text = selected_map.Name
			mission_info_left_button.hide()
			mission_info_button_spacer.hide()
			mission_info_right_button.text = "Accept"
			rewards_difficulty_container.show()
			rewards_difficulty_label.show()
			location_container.show()
			location_label.show()
		UIState.SHOP:
			main_nav_windows.hide()
			sub_nav_windows.show()
			shop_window.show()
			mission_select_window.hide()
			#mission_info_container.hide()
			populate_shop_tabs()
			pass

func continent_selected(continent: Continent) -> void:
	selected_continent = continent
	selected_map = Registry.get_maps_for_continent(continent.Name)[0] # Assuming one map per continent
	artifact_recovery_mission = continent_missions[continent.Name]["artifact"]
	cryptid_hunt_mission = continent_missions[continent.Name]["cryptid"]
	state_machine.set_state(UIState.CONTINENT_SELECT_WITH_INFO)

func _on_select_mission_pressed() -> void:
	print("Select Mission Pressed")
	state_machine.set_state(UIState.CONTINENT_SELECT)

func _on_shop_back_to_main() -> void:
	state_machine.set_state(UIState.MAIN_NAV)

func _on_mission_back_to_main_button() -> void:
	state_machine.set_state(UIState.MAIN_NAV)

func _on_mission_close_button() -> void:
	print("Mission Closed")
	continent_selected_signal.emit(null)
	state_machine.set_state(UIState.CONTINENT_SELECT)

func _on_mission_info_left_button_pressed() -> void:
	print("_on_mission_info_left_button_pressed")
	mission_selected(artifact_recovery_mission)

func _on_mission_info_right_button_pressed() -> void:
	print("_on_mission_info_right_button_pressed")
	mission_selected(cryptid_hunt_mission)

func _on_shop_button() -> void:
	state_machine.set_state(UIState.SHOP)



#
#@onready var state_machine: StateMachineComponent = $StateMachineComponent
#@onready var faith_bar: Control = $MainNavWindows/CenterItems/VBoxContainer/FaithBar
#@onready var main_nav_windows: Control = $MainNavWindows
#@onready var deploying_location_label : Control =  $MainNavWindows/CornerItems/DeployingVBox/MarginContainer/DeployingContainer/MarginContainer/DeployingLocationLabel
#@onready var sub_nav_windows: Control = $SubNavWindows
#@onready var mission_select_window: Control = $SubNavWindows/MissionSelect
#@onready var mission_info_container: Control = $SubNavWindows/MissionSelect/MissionInfoContainer
#@onready var mission_info_panel: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel
#@onready var select_mission_button: Control = $MainNavWindows/CornerItems/LeftVContainer/SelectMissionContainer_Margin/SelectMissionButton
#@onready var location_container: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/Title_Container/LocationContainer
#@onready var location_label: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/Title_Container/LocationContainer/LocationLabel
#
#@onready var cart_total_label: Control = $SubNavWindows/ShopWindow/ShopContainer/VBoxContainer/TabMarginBox/VBoxContainer/ShopBottomNav/PageControls/HBoxContainer/HBoxContainer2/Balance_Label
#@onready var purchase_button: Control = $SubNavWindows/ShopWindow/ShopContainer/VBoxContainer/TabMarginBox/VBoxContainer/ShopBottomNav/PageControls/CenterContainer/PurchaseButton
#@onready var balance_label: Control = $SubNavWindows/ShopWindow/ShopContainer/MoneyAmountContainer/MoneyLabelContainer/MoneyLabel
#
#
#@onready var rewards_difficulty_container: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/RewardsAndDifficultyContainer
#@onready var rewards_difficulty_label: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/RewardsAndDifficultyContainer/RewardsAndDifficulty
#
#@onready var shop_button: Control = $MainNavWindows/CornerItems/ShopDatabaseContainer/ShopContainer/ShopButton
#@onready var database_button: Control = $CornerItems/ShopDatabaseContainer/DatabaseContainer/DatabaseButton
#@onready var shop_window: Control = $SubNavWindows/ShopWindow
#
#@onready var mission_back_to_main: Control = $SubNavWindows/MissionSelect/BackContainer/BackToMainButton
#@onready var shop_back_to_main: Control = $SubNavWindows/ShopWindow/ShopContainer/TitleContainer/CloseShopButton
#
#@onready var continent_select_container: Control = $SubNavWindows/MissionSelect/ContinentSelectContainer
#
#@onready var asia_button: Control = $SubNavWindows/MissionSelect/ContinentSelectContainer/Asia_Button
#@onready var africa_button: Control = $SubNavWindows/MissionSelect/ContinentSelectContainer/Africa_Button
#@onready var north_america_button: Control = $SubNavWindows/MissionSelect/ContinentSelectContainer/North_America_Button
#@onready var south_america_button: Control = $SubNavWindows/MissionSelect/ContinentSelectContainer/South_America_Button
#@onready var antartica_button: Control = $SubNavWindows/MissionSelect/ContinentSelectContainer/Antarctica_Button
#@onready var europe_button: Control = $SubNavWindows/MissionSelect/ContinentSelectContainer/Europe_Button
#@onready var australia_button: Control = $SubNavWindows/MissionSelect/ContinentSelectContainer/Oceania_Button
#
#@onready var mission_back_to_main_button: Control = $SubNavWindows/MissionSelect/BackContainer/BackToMainButton
#@onready var mission_close_button: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/Title_Container/CloseButton
#@onready var mission_info_header: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/Title_Container/HeaderMarginContainer/Header
#@onready var mission_info_desc: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/MissionInfoContainer/MissionInfoText
#@onready var mission_info_left_button: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/BottomButtons/LeftButton
#@onready var mission_info_right_button: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/BottomButtons/RightButton
#@onready var mission_info_button_spacer: Control = $SubNavWindows/MissionSelect/MissionInfoContainer/InfoPanel/MissionInfo/BottomButtons/Space
#
#@onready var weapons_tab: Control = $SubNavWindows/ShopWindow/ShopContainer/VBoxContainer/TabMarginBox/VBoxContainer/ShopTabContainer/Weapons/Container/Grid
#@onready var tools_tab: Control = $SubNavWindows/ShopWindow/ShopContainer/VBoxContainer/TabMarginBox/VBoxContainer/ShopTabContainer/Tools/Container/Grid
#@onready var consumable_tab: Control = $SubNavWindows/ShopWindow/ShopContainer/VBoxContainer/TabMarginBox/VBoxContainer/ShopTabContainer/Consumable/Container/Grid
#@onready var special_tab: Control = $SubNavWindows/ShopWindow/ShopContainer/VBoxContainer/TabMarginBox/VBoxContainer/ShopTabContainer/Special/Container/Grid
#@onready var misc_tab: Control = $SubNavWindows/ShopWindow/ShopContainer/VBoxContainer/TabMarginBox/VBoxContainer/ShopTabContainer/Misc/Container/Grid
