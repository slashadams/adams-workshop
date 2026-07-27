extends RefCounted
class_name SeedData

# Seed type enum
enum Type { YELLOW, RED, BLUE, PURPLE, ORANGE, TEAL }

# Seed rarity: 0=common, 1=uncommon, 2=rare
static func get_rarity(type: int) -> int:
	match type:
		Type.YELLOW, Type.RED: return 0
		Type.BLUE, Type.PURPLE: return 1
		Type.ORANGE, Type.TEAL: return 2
		_: return 0

static func get_seed_name(type: int) -> String:
	match type:
		Type.YELLOW: return "Sunseed"
		Type.RED: return "Crimson Berry"
		Type.BLUE: return "Lapis Bloom"
		Type.PURPLE: return "Twilight Vine"
		Type.ORANGE: return "Amber Spore"
		Type.TEAL: return "Verdant Pearl"
		_: return "Unknown Seed"

static func get_sell_price(type: int) -> int:
	match type:
		Type.YELLOW: return 5
		Type.RED: return 5
		Type.BLUE: return 15
		Type.PURPLE: return 15
		Type.ORANGE: return 40
		Type.TEAL: return 40
		_: return 5

static func get_buy_price(type: int) -> int:
	return get_sell_price(type) * 2

static func get_texture_rect(type: int) -> Rect2:
	var x = type * 16
	return Rect2(x, 0, 16, 16)

static func get_hybrid(parent_a: int, parent_b: int) -> int:
	var combo = [mini(parent_a, parent_b), maxi(parent_a, parent_b)]
	if combo == [Type.YELLOW, Type.RED]: return Type.BLUE
	if combo == [Type.YELLOW, Type.BLUE]: return Type.PURPLE
	if combo == [Type.RED, Type.BLUE]: return Type.PURPLE
	if combo == [Type.BLUE, Type.PURPLE]: return Type.ORANGE
	if combo == [Type.YELLOW, Type.PURPLE]: return Type.ORANGE
	if combo == [Type.RED, Type.PURPLE]: return Type.TEAL
	if combo == [Type.ORANGE, Type.TEAL]: return Type.ORANGE
	if combo == [Type.YELLOW, Type.ORANGE]: return Type.TEAL
	if combo == [Type.RED, Type.ORANGE]: return Type.TEAL
	if combo == [Type.BLUE, Type.ORANGE]: return Type.ORANGE
	if combo == [Type.YELLOW, Type.TEAL]: return Type.TEAL
	if combo == [Type.RED, Type.TEAL]: return Type.ORANGE
	if combo == [Type.BLUE, Type.TEAL]: return Type.TEAL
	if parent_a == parent_b: return parent_a
	return parent_a
