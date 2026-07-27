extends Node2D

@onready var player = $Player
@onready var tilemap = $TileMapLayer
@onready var pickups_container = $Pickups
@onready var audio_collect = $CollectSound
@onready var inventory_ui = $CanvasLayer/InventoryUI
@onready var hud_label = $CanvasLayer/HUD/GoldLabel

var grass_positions: Array[Vector2] = []
var active_pickups_count: int = 0
const MAX_PICKUPS: int = 5
const MIN_PICKUPS: int = 3

func _ready() -> void:
	_collect_grass_positions()
	_spawn_initial_seeds()
	
	if SeedManager:
		SeedManager.gold_changed.connect(_on_gold_changed)
		_on_gold_changed(SeedManager.gold)
	
	var exit_area = $GardenExitArea
	if exit_area:
		exit_area.body_entered.connect(_on_garden_exit_body_entered)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			if inventory_ui:
				inventory_ui.toggle()

func _on_gold_changed(amount: int) -> void:
	if hud_label:
		hud_label.text = "Gold: " + str(amount)

func _collect_grass_positions() -> void:
	grass_positions.clear()
	if not tilemap:
		for x in range(2, 18):
			for y in range(2, 12):
				grass_positions.append(Vector2(x * 32 + 16, y * 32 + 16))
		return
	
	var used_cells = tilemap.get_used_cells()
	for cell in used_cells:
		var atlas_coords = tilemap.get_cell_atlas_coords(cell)
		if atlas_coords.x == 0: # 0 = grass tile
			var world_pos = tilemap.map_to_local(cell)
			grass_positions.append(world_pos)

func _spawn_initial_seeds() -> void:
	var count = randi_range(MIN_PICKUPS, MAX_PICKUPS)
	for i in range(count):
		_spawn_seed()

func _choose_random_seed_type() -> int:
	var r = randf()
	if r < 0.55:
		return SeedData.Type.YELLOW if randf() < 0.5 else SeedData.Type.RED
	elif r < 0.85:
		return SeedData.Type.BLUE if randf() < 0.5 else SeedData.Type.PURPLE
	else:
		return SeedData.Type.ORANGE if randf() < 0.5 else SeedData.Type.TEAL

func _spawn_seed() -> void:
	if grass_positions.is_empty():
		return
	
	var spawn_pos = grass_positions.pick_random()
	var seed_type = _choose_random_seed_type()
	
	var pickup = Area2D.new()
	pickup.position = spawn_pos
	
	var sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/seeds.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.region_enabled = true
	sprite.region_rect = SeedData.get_texture_rect(seed_type)
	pickup.add_child(sprite)
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 12.0
	col.shape = shape
	pickup.add_child(col)
	
	pickup.body_entered.connect(func(body):
		if body == player:
			_on_pickup_collected(pickup, seed_type)
	)
	
	pickups_container.add_child(pickup)
	active_pickups_count += 1

func _on_pickup_collected(pickup: Area2D, seed_type: int) -> void:
	if not is_instance_valid(pickup):
		return
	
	pickup.queue_free()
	active_pickups_count -= 1
	
	if audio_collect:
		audio_collect.play()
	
	SeedManager.add_seed(seed_type, 1)
	
	var timer = get_tree().create_timer(randf_range(3.0, 5.0))
	timer.timeout.connect(func():
		if active_pickups_count < MAX_PICKUPS:
			_spawn_seed()
	)

func _on_garden_exit_body_entered(body: Node2D) -> void:
	if body == player:
		get_tree().change_scene_to_file("res://scenes/garden.tscn")
