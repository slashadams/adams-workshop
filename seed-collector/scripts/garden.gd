extends Node2D

@onready var player = $Player
@onready var shop_npc = $ShopNPC
@onready var plots_container = $GardenPlots
@onready var inventory_ui = $CanvasLayer/InventoryUI
@onready var shop_ui = $CanvasLayer/ShopUI
@onready var plant_menu = $CanvasLayer/PlantMenu
@onready var seeds_item_list = $CanvasLayer/PlantMenu/Panel/VBoxContainer/ItemList
@onready var action_popup = $CanvasLayer/ActionPopup
@onready var action_vbox = $CanvasLayer/ActionPopup/Panel/VBoxContainer
@onready var hud_label = $CanvasLayer/HUD/GoldLabel
@onready var notif_label = $CanvasLayer/HUD/NotificationLabel

@onready var audio_plant = $Sounds/PlantSound
@onready var audio_harvest = $Sounds/HarvestSound
@onready var audio_menu = $Sounds/MenuSound

var plot_positions: Array[Vector2] = []
var plot_sprites: Array[Sprite2D] = []
var selected_plot_index: int = -1

func _ready() -> void:
	_setup_plots()
	
	if player:
		player.interact_pressed.connect(_on_player_interact)
	
	if SeedManager:
		SeedManager.plot_changed.connect(_on_plot_changed)
		SeedManager.gold_changed.connect(_on_gold_changed)
		SeedManager.notification_message.connect(_on_notification)
		_on_gold_changed(SeedManager.gold)
		
		for i in range(SeedManager.garden_plots.size()):
			_on_plot_changed(i)
	
	var world_exit = $WorldExitArea
	if world_exit:
		world_exit.body_entered.connect(_on_world_exit_body_entered)
	
	if plant_menu:
		plant_menu.hide()
	if action_popup:
		action_popup.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			if inventory_ui:
				inventory_ui.toggle()
		elif event.keycode == KEY_ESCAPE:
			if plant_menu and plant_menu.visible:
				plant_menu.hide()
			elif action_popup and action_popup.visible:
				action_popup.hide()

func _setup_plots() -> void:
	plot_positions.clear()
	plot_sprites.clear()
	
	var base_x = 272.0
	var base_y = 176.0
	var spacing_x = 32.0
	var spacing_y = 32.0
	
	for i in range(6):
		var row = i / 3
		var col = i % 3
		var pos = Vector2(base_x + col * spacing_x, base_y + row * spacing_y)
		plot_positions.append(pos)
		
		var sprite = Sprite2D.new()
		sprite.position = pos
		sprite.texture = load("res://assets/sprites/plants.png")
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.region_enabled = true
		sprite.scale = Vector2(2, 2)
		sprite.visible = false
		plots_container.add_child(sprite)
		plot_sprites.append(sprite)

func _on_gold_changed(amount: int) -> void:
	if hud_label:
		hud_label.text = "Gold: " + str(amount) + "g"

func _on_notification(msg: String) -> void:
	if notif_label:
		notif_label.text = msg
		var timer = get_tree().create_timer(3.0)
		timer.timeout.connect(func():
			if notif_label.text == msg:
				notif_label.text = ""
		)

func _on_plot_changed(plot_index: int) -> void:
	if plot_index < 0 or plot_index >= plot_sprites.size():
		return
	var sprite = plot_sprites[plot_index]
	var plot = SeedManager.garden_plots[plot_index]
	
	if plot["planted"]:
		sprite.visible = true
		var seed_type: int = plot["seed_type"]
		var stage: int = plot["growth_stage"]
		var plant_type: int = seed_type % 4
		var col_idx = (plant_type * 4) + stage
		sprite.region_rect = Rect2(col_idx * 4, 0, 4, 16)
	else:
		sprite.visible = false

func _on_player_interact() -> void:
	if not player:
		return
	
	if plant_menu and plant_menu.visible:
		return
	if action_popup and action_popup.visible:
		return
	
	if shop_npc and player.global_position.distance_to(shop_npc.global_position) < 48.0:
		if audio_menu:
			audio_menu.play()
		if shop_ui:
			shop_ui.toggle()
		return
	
	var closest_idx = -1
	var closest_dist = 99999.0
	for i in range(plot_positions.size()):
		var dist = player.global_position.distance_to(plot_positions[i])
		if dist < closest_dist:
			closest_dist = dist
			closest_idx = i
	
	if closest_idx != -1 and closest_dist < 48.0:
		_handle_plot_interaction(closest_idx)

func _handle_plot_interaction(plot_index: int) -> void:
	selected_plot_index = plot_index
	var plot = SeedManager.garden_plots[plot_index]
	
	if not plot["planted"]:
		_open_plant_menu(plot_index)
	elif plot["growth_stage"] < 3:
		SeedManager.water_plot(plot_index)
		if audio_plant:
			audio_plant.play()
	else:
		_open_harvest_or_crossbreed_menu(plot_index)

func _open_plant_menu(plot_index: int) -> void:
	if not plant_menu or not seeds_item_list:
		return
	
	seeds_item_list.clear()
	var available_seeds = []
	for st in SeedData.Type.values():
		var count = SeedManager.get_seed_count(st)
		if count > 0:
			available_seeds.append(st)
			var idx = seeds_item_list.add_item(SeedData.get_seed_name(st) + " (x" + str(count) + ")")
			seeds_item_list.set_item_metadata(idx, st)
	
	if available_seeds.is_empty():
		SeedManager.notification_message.emit("No seeds in inventory to plant!")
		return
	
	if seeds_item_list.item_selected.is_connected(_on_seed_item_selected):
		seeds_item_list.item_selected.disconnect(_on_seed_item_selected)
	seeds_item_list.item_selected.connect(_on_seed_item_selected)
	
	plant_menu.visible = true

func _on_seed_item_selected(index: int) -> void:
	if selected_plot_index == -1 or not seeds_item_list:
		return
	var seed_type = seeds_item_list.get_item_metadata(index)
	if SeedManager.plant_seed(selected_plot_index, seed_type):
		if audio_plant:
			audio_plant.play()
	if plant_menu:
		plant_menu.visible = false

func _open_harvest_or_crossbreed_menu(plot_index: int) -> void:
	if not action_popup or not action_vbox:
		return
	
	for child in action_vbox.get_children():
		child.queue_free()
	
	var label = Label.new()
	label.text = "Plot " + str(plot_index + 1) + " Options:"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_vbox.add_child(label)
	
	var btn_harvest = Button.new()
	btn_harvest.text = "Harvest Seed & Gold"
	btn_harvest.pressed.connect(func():
		action_popup.visible = false
		SeedManager.harvest_plot(plot_index)
		if audio_harvest:
			audio_harvest.play()
	)
	action_vbox.add_child(btn_harvest)
	
	var mature_other_plots = []
	for i in range(SeedManager.garden_plots.size()):
		if i != plot_index and SeedManager.can_crossbreed(plot_index, i):
			mature_other_plots.append(i)
	
	for other_idx in mature_other_plots:
		var btn_cross = Button.new()
		var other_seed = SeedManager.garden_plots[other_idx]["seed_type"]
		btn_cross.text = "Crossbreed with Plot " + str(other_idx + 1) + " (" + SeedData.get_seed_name(other_seed) + ")"
		btn_cross.pressed.connect(func():
			action_popup.visible = false
			SeedManager.crossbreed(plot_index, other_idx)
			if audio_harvest:
				audio_harvest.play()
		)
		action_vbox.add_child(btn_cross)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "Cancel"
	btn_cancel.pressed.connect(func():
		action_popup.visible = false
	)
	action_vbox.add_child(btn_cancel)
	
	action_popup.visible = true

func _on_world_exit_body_entered(body: Node2D) -> void:
	if body == player:
		get_tree().change_scene_to_file("res://scenes/world.tscn")
