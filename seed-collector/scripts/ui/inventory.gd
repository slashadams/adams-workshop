extends Control

@onready var grid_container = $Panel/GridContainer
@onready var close_button = $Panel/CloseButton
@onready var title_label = $Panel/TitleLabel

var slot_nodes: Array[Control] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if SeedManager:
		SeedManager.inventory_changed.connect(refresh_inventory)
	
	if close_button:
		close_button.pressed.connect(close)
	
	_create_slots()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB:
			close()
			get_viewport().set_input_as_handled()

func _create_slots() -> void:
	if not grid_container:
		return
	
	for child in grid_container.get_children():
		child.queue_free()
	slot_nodes.clear()
	
	for i in range(12):
		var slot_panel = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(48, 48)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_panel.add_child(vbox)
		
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.name = "Icon"
		vbox.add_child(icon)
		
		var count_lbl = Label.new()
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.add_theme_font_size_override("font_size", 10)
		count_lbl.name = "CountLabel"
		vbox.add_child(count_lbl)
		
		grid_container.add_child(slot_panel)
		slot_nodes.append(slot_panel)
	
	refresh_inventory()

func refresh_inventory() -> void:
	if slot_nodes.is_empty():
		return
	
	var seed_types = SeedData.Type.values()
	for i in range(12):
		var slot = slot_nodes[i]
		var icon = slot.find_child("Icon", true, false) as TextureRect
		var count_lbl = slot.find_child("CountLabel", true, false) as Label
		
		if i < seed_types.size():
			var st = seed_types[i]
			var count = SeedManager.get_seed_count(st)
			if count > 0:
				var atlas_tex = AtlasTexture.new()
				atlas_tex.atlas = load("res://assets/sprites/seeds.png")
				atlas_tex.region = SeedData.get_texture_rect(st)
				icon.texture = atlas_tex
				icon.visible = true
				count_lbl.text = "x" + str(count)
				slot.tooltip_text = SeedData.get_seed_name(st) + "\nSell Price: " + str(SeedData.get_sell_price(st)) + "g"
			else:
				icon.texture = null
				icon.visible = false
				count_lbl.text = ""
				slot.tooltip_text = "Empty"
		else:
			icon.texture = null
			icon.visible = false
			count_lbl.text = ""
			slot.tooltip_text = "Empty"

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	refresh_inventory()
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false
