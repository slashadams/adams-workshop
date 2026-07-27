extends Control

@onready var gold_label = $Panel/GoldLabel
@onready var buy_container = $Panel/TabContainer/Buy/VBoxContainer
@onready var sell_container = $Panel/TabContainer/Sell/VBoxContainer
@onready var close_button = $Panel/CloseButton

@onready var buy_sound = $BuySound
@onready var sell_sound = $SellSound

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if SeedManager:
		SeedManager.gold_changed.connect(_on_gold_changed)
		SeedManager.inventory_changed.connect(refresh_sell_list)
	
	if close_button:
		close_button.pressed.connect(close)
	
	_setup_buy_list()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()

func _on_gold_changed(amount: int) -> void:
	if gold_label:
		gold_label.text = "Gold: " + str(amount) + "g"

func _setup_buy_list() -> void:
	if not buy_container:
		return
	
	for child in buy_container.get_children():
		child.queue_free()
	
	var buyable_seeds = [SeedData.Type.YELLOW, SeedData.Type.RED, SeedData.Type.BLUE]
	for st in buyable_seeds:
		var hbox = HBoxContainer.new()
		
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = load("res://assets/sprites/seeds.png")
		atlas_tex.region = SeedData.get_texture_rect(st)
		icon.texture = atlas_tex
		hbox.add_child(icon)
		
		var label = Label.new()
		label.text = SeedData.get_seed_name(st) + " - " + str(SeedData.get_buy_price(st)) + "g"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)
		
		var buy_btn = Button.new()
		buy_btn.text = "Buy"
		buy_btn.pressed.connect(func():
			_buy_seed(st)
		)
		hbox.add_child(buy_btn)
		
		buy_container.add_child(hbox)

func refresh_sell_list() -> void:
	if not sell_container:
		return
	
	for child in sell_container.get_children():
		child.queue_free()
	
	var has_items = false
	for st in SeedData.Type.values():
		var count = SeedManager.get_seed_count(st)
		if count > 0:
			has_items = true
			var hbox = HBoxContainer.new()
			
			var icon = TextureRect.new()
			icon.custom_minimum_size = Vector2(24, 24)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var atlas_tex = AtlasTexture.new()
			atlas_tex.atlas = load("res://assets/sprites/seeds.png")
			atlas_tex.region = SeedData.get_texture_rect(st)
			icon.texture = atlas_tex
			hbox.add_child(icon)
			
			var label = Label.new()
			label.text = SeedData.get_seed_name(st) + " (x" + str(count) + ") - " + str(SeedData.get_sell_price(st)) + "g ea"
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(label)
			
			var sell_btn = Button.new()
			sell_btn.text = "Sell 1"
			sell_btn.pressed.connect(func():
				_sell_seed(st)
			)
			hbox.add_child(sell_btn)
			
			sell_container.add_child(hbox)
	
	if not has_items:
		var empty_lbl = Label.new()
		empty_lbl.text = "No seeds to sell!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sell_container.add_child(empty_lbl)

func _buy_seed(st: int) -> void:
	var price = SeedData.get_buy_price(st)
	if SeedManager.spend_gold(price):
		SeedManager.add_seed(st, 1)
		if buy_sound:
			buy_sound.play()
		SeedManager.notification_message.emit("Bought " + SeedData.get_seed_name(st) + "!")
	else:
		SeedManager.notification_message.emit("Not enough gold!")

func _sell_seed(st: int) -> void:
	if SeedManager.remove_seed(st, 1):
		var price = SeedData.get_sell_price(st)
		SeedManager.add_gold(price)
		if sell_sound:
			sell_sound.play()
		SeedManager.notification_message.emit("Sold 1x " + SeedData.get_seed_name(st) + " for " + str(price) + "g!")

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	if SeedManager:
		_on_gold_changed(SeedManager.gold)
	refresh_sell_list()
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false
