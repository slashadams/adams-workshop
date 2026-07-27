extends Node

signal inventory_changed
signal gold_changed(new_gold: int)
signal plot_changed(plot_index: int)
signal seed_collected(type: int)
signal notification_message(msg: String)

var inventory: Dictionary = {}
var gold: int = 20
var garden_plots: Array = []
var total_collected: int = 0
var crossbreeds_discovered: Array = []

func _ready() -> void:
	if garden_plots.is_empty():
		for i in range(6):
			garden_plots.append({
				"planted": false,
				"seed_type": 0,
				"growth_stage": 0,
				"time_planted": 0.0
			})

func add_seed(type: int, count: int = 1) -> void:
	if count <= 0:
		return
	var current = inventory.get(type, 0)
	inventory[type] = current + count
	total_collected += count
	inventory_changed.emit()
	seed_collected.emit(type)

func remove_seed(type: int, count: int = 1) -> bool:
	var current = inventory.get(type, 0)
	if current >= count:
		inventory[type] = current - count
		if inventory[type] == 0:
			inventory.erase(type)
		inventory_changed.emit()
		return true
	return false

func get_seed_count(type: int) -> int:
	return inventory.get(type, 0)

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false

func plant_seed(plot_index: int, seed_type: int) -> bool:
	if plot_index < 0 or plot_index >= garden_plots.size():
		return false
	var plot = garden_plots[plot_index]
	if plot["planted"]:
		return false
	if remove_seed(seed_type, 1):
		plot["planted"] = true
		plot["seed_type"] = seed_type
		plot["growth_stage"] = 0
		plot["time_planted"] = Time.get_unix_time_from_system()
		plot_changed.emit(plot_index)
		notification_message.emit("Planted " + SeedData.get_seed_name(seed_type) + "!")
		return true
	return false

func water_plot(plot_index: int) -> void:
	if plot_index < 0 or plot_index >= garden_plots.size():
		return
	var plot = garden_plots[plot_index]
	if plot["planted"] and plot["growth_stage"] < 3:
		plot["growth_stage"] += 1
		plot_changed.emit(plot_index)
		if plot["growth_stage"] == 3:
			notification_message.emit("Plant in plot " + str(plot_index + 1) + " is fully grown!")
		else:
			notification_message.emit("Watered plot " + str(plot_index + 1) + "!")

func harvest_plot(plot_index: int) -> int:
	if plot_index < 0 or plot_index >= garden_plots.size():
		return -1
	var plot = garden_plots[plot_index]
	if not plot["planted"] or plot["growth_stage"] < 3:
		return -1
	
	var harvested_type: int = plot["seed_type"]
	add_seed(harvested_type, 1)
	var bonus_gold = SeedData.get_sell_price(harvested_type)
	add_gold(bonus_gold)
	
	plot["planted"] = false
	plot["seed_type"] = 0
	plot["growth_stage"] = 0
	plot["time_planted"] = 0.0
	plot_changed.emit(plot_index)
	
	notification_message.emit("Harvested " + SeedData.get_seed_name(harvested_type) + " (+1 seed, +" + str(bonus_gold) + "g)!")
	return harvested_type

func can_crossbreed(plot_a: int, plot_b: int) -> bool:
	if plot_a < 0 or plot_a >= garden_plots.size():
		return false
	if plot_b < 0 or plot_b >= garden_plots.size():
		return false
	if plot_a == plot_b:
		return false
	var p_a = garden_plots[plot_a]
	var p_b = garden_plots[plot_b]
	return p_a["planted"] and p_a["growth_stage"] == 3 and p_b["planted"] and p_b["growth_stage"] == 3

func crossbreed(plot_a: int, plot_b: int) -> int:
	if not can_crossbreed(plot_a, plot_b):
		return -1
	
	var type_a: int = garden_plots[plot_a]["seed_type"]
	var type_b: int = garden_plots[plot_b]["seed_type"]
	var hybrid_type: int = SeedData.get_hybrid(type_a, type_b)
	
	var combo = [mini(type_a, type_b), maxi(type_a, type_b), hybrid_type]
	if not combo in crossbreeds_discovered:
		crossbreeds_discovered.append(combo)
	
	add_seed(hybrid_type, 1)
	
	garden_plots[plot_a]["planted"] = false
	garden_plots[plot_a]["seed_type"] = 0
	garden_plots[plot_a]["growth_stage"] = 0
	
	garden_plots[plot_b]["planted"] = false
	garden_plots[plot_b]["seed_type"] = 0
	garden_plots[plot_b]["growth_stage"] = 0
	
	plot_changed.emit(plot_a)
	plot_changed.emit(plot_b)
	
	notification_message.emit("Crossbred! Created " + SeedData.get_seed_name(hybrid_type) + "!")
	return hybrid_type

func save_game() -> void:
	pass

func load_game() -> void:
	pass
