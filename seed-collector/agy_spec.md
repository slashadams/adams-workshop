# Seed Collector — Godot 4 GDScript Spec

## Game Overview
A relaxing 2D pixel-art game where you explore a small world, collect seeds, and grow them in your garden. Crossbreed plants to discover rare hybrids. Play at your own pace — no timers, no combat, no fail states.

## Project Setup
- Engine: Godot 4.7.1 (GL Compatibility renderer)
- Resolution: 640x480, stretch mode "viewport" with "keep" aspect
- Autoload: `res://scripts/seed_manager.gd` as "SeedManager"
- All sprites use pixel-art nearest-neighbor filtering (no interpolation)

## Asset Reference (res://assets/sprites/)
- **tiles.png** — 192x32 tileset, 32px tiles. Indices: 0=grass, 1=dirt, 2=water, 3=path, 4=garden_plot, 5=fence
- **player.png** — 32x32 RGBA, 16px cells. Left half=idle frame, right half=walk frame
- **seeds.png** — 96x16 RGBA, 16px icons. 6 seeds: yellow, red, blue, purple, orange, teal
- **plants.png** — 64x16 RGBA, 4px×16px per stage. 4 plant types, 4 growth stages each
- **ui.png** — 128x32 RGBA. Sections: [0-32]=button, [32-64]=inv_slot, [64-80]=coin, [80-96]=heart, [96-112]=highlight, [112-128]=crossbreed

## Sound Reference (res://assets/sounds/)
- collect.wav, plant.wav, step.wav, harvest.wav, buy.wav, sell.wav, menu.wav

## Scene Structure

### res://scenes/main.tscn (Main Menu)
- Title "Seed Collector" centered
- "New Game" button → starts player in garden scene
- "Quit" button → quit

### res://scenes/garden.tscn (Garden Scene)
- The player's home base. A small garden area with:
  - Tilemap using grass, dirt, path tiles
  - 6 garden plots (TileMap tiles using index 4 = garden_plot) arranged in a 2x3 grid
  - A path leading off-screen to the "wilds" (transition to world scene)
  - A small "shop" area with an NPC sprite (simple colored rectangle)
- Player can walk freely in the garden
- Walking near a plot and pressing "interact" (E key / Space) opens plant/collect UI
- Walking near the shop NPC opens the shop UI
- Walking to the edge/path transitions to world scene

### res://scenes/world.tscn (Exploration World)
- A larger area with grass, dirt, water, and path tiles
- Seeds spawn randomly on grass tiles (3-5 visible at a time)
- Seeds are small sprites (16x16 from seeds.png) hovering above the ground
- Player walks over a seed → auto-collects it (collect.wav plays)
- Collected seeds go into inventory
- An edge path leads back to garden scene
- After collecting, a new seed respawns somewhere else after a short delay

### res://scenes/ui/inventory.tscn (Inventory UI)
- Opens with Tab key
- Grid of slots showing collected seeds
- Each slot shows seed icon + count
- Game pauses when inventory is open
- Close with Tab or Escape

### res://scenes/ui/shop.tscn (Shop UI)
- Opens when near the shop NPC and pressing interact
- Lists 3 basic seeds for sale (yellow, red, blue) with prices
- Shows player's current gold
- Buy: clicking a seed deducts gold, adds seed to inventory
- Sell: player can click inventory seeds to sell at half price
- Close with Escape

## Scripts to Create

### res://scripts/seed_data.gd
A static data class:
```gdscript
extends Resource
class_name SeedData

# Seed type enum
enum Type { YELLOW, RED, BLUE, PURPLE, ORANGE, TEAL }

# Seed rarity: 0=common, 1=uncommon, 2=rare
static func get_rarity(type: Type) -> int:
    match type:
        Type.YELLOW, Type.RED: return 0
        Type.BLUE, Type.PURPLE: return 1
        Type.ORANGE, Type.TEAL: return 2

static func get_name(type: Type) -> String:
    match type:
        Type.YELLOW: return "Sunseed"
        Type.RED: return "Crimson Berry"
        Type.BLUE: return "Lapis Bloom"
        Type.PURPLE: return "Twilight Vine"
        Type.ORANGE: return "Amber Spore"
        Type.TEAL: return "Verdant Pearl"

static func get_sell_price(type: Type) -> int:
    match type:
        Type.YELLOW: return 5
        Type.RED: return 5
        Type.BLUE: return 15
        Type.PURPLE: return 15
        Type.ORANGE: return 40
        Type.TEAL: return 40

static func get_buy_price(type: Type) -> int:
    return get_sell_price(type) * 2

static func get_texture_rect(type: Type) -> Rect2:
    # Returns the rect in seeds.png for this seed type
    var x = type * 16
    return Rect2(x, 0, 16, 16)

# Crossbreeding: given two parent types, what hybrid do they produce?
static func get_hybrid(parent_a: Type, parent_b: Type) -> Type:
    # Simple combination logic
    var combo = [min(parent_a, parent_b), max(parent_a, parent_b)]
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
    # Same types or no cross: just return the parent
    if parent_a == parent_b: return parent_a
    return parent_a
```

### res://scripts/seed_manager.gd (Autoload)
Global game state manager:
- `inventory: Dictionary` — seed_type -> count (e.g., {0: 3, 1: 5})
- `gold: int` — starts at 20
- `garden_plots: Array` — array of 6 plots, each with {planted: bool, seed_type: int, growth_stage: int, time_planted: float}
- `total_collected: int` — lifetime seeds collected
- `crossbreeds_discovered: Array` — list of [parent_a, parent_b, result] discovered
- Methods:
  - `add_seed(type: int, count: int = 1)`
  - `remove_seed(type: int, count: int = 1) -> bool`
  - `get_seed_count(type: int) -> int`
  - `add_gold(amount: int)`
  - `spend_gold(amount: int) -> bool`
  - `plant_seed(plot_index: int, seed_type: int) -> bool`
  - `water_plot(plot_index: int)` — advances growth stage by 1 (max 3)
  - `harvest_plot(plot_index: int) -> int` — returns seed type harvested
  - `can_crossbreed(plot_a: int, plot_b: int) -> bool`
  - `crossbreed(plot_a: int, plot_b: int) -> int` — returns new seed type
  - `save_game() / load_game()` — placeholder for future save system

### res://scripts/player.gd
Attached to player scene (Area2D or CharacterBody2D):
- 16x16 sprite using res://assets/sprites/player.png
- Move with WASD or arrow keys at 60px/s
- Animate: alternate between left/right half of spritesheet when moving
- 4-directional movement (no diagonal)
- Interact: press E or Space near interactable objects
- World edge: if player reaches a transition zone, call scene switch
- Collision shape: 12x10 rectangle centered at bottom of sprite

### res://scripts/world.gd
Attached to world scene:
- Spawns 3-5 seed pickups on grass tiles
- Each seed pickup: AnimatedSprite2D using seeds.png region
- When player overlaps a pickup, emit signal, play collect.wav, remove pickup
- After collection, wait 3-5 seconds, respawn a new seed at a random grass tile
- Seeds that are common (yellow, red) spawn more frequently than rare ones
- Transition zone: if player reaches the garden exit area, switch to garden scene

### res://scripts/garden.gd
Attached to garden scene:
- Creates 6 garden plots (TileMap cells with index 4)
- Each plot tracks: seed type planted, growth stage (0-3)
- Display plant growth using plants.png regions
- When player interacts near a plot:
  - If empty: show "Plant seed" menu (pick from inventory)
  - If growing: show "Water" option (advances growth)
  - If fully grown (stage 3): show "Harvest" option (gives seed + gold)
  - If two adjacent plots are fully grown: show "Crossbreed" option
- Shop NPC: simple sprite, when player interacts near it, open shop UI
- Path to world: transition zone to world scene

### res://scripts/ui/inventory.gd
- Grid of 12 slots (2 rows × 6 columns)
- Each slot shows seed icon (from seeds.png) and count
- Highlight selected slot with border from ui.png
- Tab to toggle, Escape to close, game paused while open

### res://scripts/ui/shop.gd
- Lists 3 basic seeds (yellow, red, blue) with buy prices
- Shows player gold
- Buy button per seed (deducts gold, adds to inventory)
- Sell tab: shows inventory seeds, click to sell at half price
- Must be near shop NPC to use

## Tilemap Setup
- Use TileSet from tiles.png with 32px tiles
- 6 tiles indexed 0-5
- Collision on water tiles (index 2) — player cannot walk on water
- Collision on fence tiles (index 5) — player cannot walk through fences

## Important Notes
- Use nearest-neighbor texture filtering on all sprites (no smoothing)
- Player should always be drawn on top of tiles
- UI should be a separate CanvasLayer that sits on top of game world
- Scene transitions should fade in/out (use a ColorRect overlay with AnimationPlayer)
- Keep the game soft and relaxing — green/blue color tones, gentle sounds
- No death, no fail states, no time pressure