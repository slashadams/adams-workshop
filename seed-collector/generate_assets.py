#!/usr/bin/env python3
"""Generate pixel art assets for Seed Collector game."""

from PIL import Image
import os

ASSETS = "/root/seed-collector/assets/sprites"

def generate_icon():
    """16x16 seed icon for the game."""
    img = Image.new("RGB", (16, 16), (0, 0, 0))
    # Sprout shape
    green = (80, 180, 60)
    brown = (120, 80, 40)
    for x in range(5, 11):
        for y in range(10, 14):
            img.putpixel((x, y), brown)  # pot
    for y in range(6, 11):
        img.putpixel((7, y), green)  # stem
    img.putpixel((7, 6), green)
    img.putpixel((6, 7), green)
    img.putpixel((8, 7), green)
    img.putpixel((7, 8), green)
    # Leaf
    img.putpixel((6, 8), (100, 220, 80))
    img.putpixel((8, 8), (100, 220, 80))
    img.save(os.path.join(ASSETS, "../icon.png"))
    # Also save as icon.png in root
    img.save("/root/seed-collector/icon.png")

def generate_tiles():
    """32x32 tileset: grass, dirt, water, path, garden_plot, fence."""
    img = Image.new("RGB", (192, 32), (0, 0, 0))
    
    # 0: Grass
    grass = (100, 180, 60)
    for x in range(32):
        for y in range(32):
            g = grass[1] + (hash((x, y)) % 20 - 10)
            img.putpixel((x, y), (grass[0] + hash((x+1, y)) % 10 - 5, g, grass[2] + hash((x, y+1)) % 10 - 5))
    
    # 1: Dirt
    dirt = (160, 130, 80)
    for x in range(32, 64):
        for y in range(32):
            d = dirt[1] + (hash((x, y)) % 15 - 7)
            img.putpixel((x, y), (dirt[0] + hash((x, y)) % 10 - 5, d, dirt[2] + hash((x, y)) % 10 - 5))
    
    # 2: Water
    water = (60, 100, 200)
    for x in range(64, 96):
        for y in range(32):
            b = water[2] + (hash((x, y)) % 10 - 5)
            img.putpixel((x, y), (water[0] + hash((x, y)) % 5 - 2, water[1] + hash((x, y)) % 5 - 2, b))
    
    # 3: Path
    path = (190, 170, 130)
    for x in range(96, 128):
        for y in range(32):
            p = path[1] + (hash((x, y)) % 15 - 7)
            img.putpixel((x, y), (path[0] + hash((x, y)) % 10 - 5, p, path[2] + hash((x, y)) % 10 - 5))
    
    # 4: Garden plot (tilled dark soil)
    plot = (100, 70, 40)
    for x in range(128, 160):
        for y in range(32):
            p = plot[1] + (hash((x, y)) % 10 - 5)
            c = plot[0] + hash((x, y)) % 10 - 5
            img.putpixel((x, y), (c, p, plot[2] + hash((x, y)) % 5 - 2))
        # edge lines
        for y in range(0, 32, 2):
            img.putpixel((x, y), (80, 50, 20))
    
    # 5: Fence
    wood = (140, 100, 50)
    for x in range(160, 192):
        for y in range(32):
            if y < 4 or y > 28 or (y > 12 and y < 20):
                img.putpixel((x, y), wood)
            elif x % 8 < 4 and (y < 8 or y > 24):
                img.putpixel((x, y), (150, 110, 55))
            else:
                # transparent bg behind fence
                g = grass[1] + (hash((x, y)) % 20 - 10)
                img.putpixel((x, y), (grass[0] + hash((x+1, y)) % 10 - 5, g, grass[2] + hash((x, y+1)) % 10 - 5))
    
    img.save(os.path.join(ASSETS, "tiles.png"))

def generate_player():
    """16x16 character spritesheet: 4 dirs x 2 frames = 32x32"""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    
    body = (240, 200, 140)  # skin
    hat = (80, 160, 200)    # blue hat
    shirt = (60, 160, 80)   # green shirt
    pants = (100, 80, 60)   # brown pants
    shoes = (60, 50, 40)
    
    # Frame 0: standing (left half)
    for y in range(16):
        for x in range(16):
            # Hat
            if y < 4 and (x > 3 and x < 12):
                img.putpixel((x, y), hat)
            # Hair
            if y == 4 and (x > 3 and x < 12):
                img.putpixel((x, y), (180, 140, 80))
            # Face
            if y == 5 and x > 4 and x < 10:
                img.putpixel((x, y), body)
            if y == 6 and x > 4 and x < 10:
                img.putpixel((x, y), body)
            # Eyes
            if y == 6 and (x == 6 or x == 8):
                img.putpixel((x, y), (0, 0, 0))
            # Body
            if y > 6 and y < 12 and x > 4 and x < 11:
                img.putpixel((x, y), shirt)
            # Arms
            if (y > 7 and y < 11) and (x == 4 or x == 11):
                img.putpixel((x, y), body)
            # Pants
            if y > 11 and y < 15 and x > 5 and x < 10:
                img.putpixel((x, y), pants)
            # Shoes
            if y == 15 and (x > 5 and x < 10):
                img.putpixel((x, y), shoes)
    
    # Frame 1: walking (right half) - slight leg offset
    for y in range(16):
        for x_offset in range(16):
            x = x_offset + 16
            # Same as frame 0 for most
            if y < 4 and (x_offset > 3 and x_offset < 12):
                img.putpixel((x, y), hat)
            if y == 4 and (x_offset > 3 and x_offset < 12):
                img.putpixel((x, y), (180, 140, 80))
            if y == 5 and x_offset > 4 and x_offset < 10:
                img.putpixel((x, y), body)
            if y == 6 and x_offset > 4 and x_offset < 10:
                img.putpixel((x, y), body)
            if y == 6 and (x_offset == 6 or x_offset == 8):
                img.putpixel((x, y), (0, 0, 0))
            if y > 6 and y < 12 and x_offset > 4 and x_offset < 11:
                img.putpixel((x, y), shirt)
            if (y > 7 and y < 11) and (x_offset == 4 or x_offset == 11):
                img.putpixel((x, y), body)
            # Walking legs offset
            if y > 11 and y < 15:
                if x_offset == 6:
                    img.putpixel((x, y), pants)
                if x_offset == 8:
                    img.putpixel((x, y), pants)
            if y == 15:
                if x_offset == 6:
                    img.putpixel((x, y), shoes)
                if x_offset == 8:
                    img.putpixel((x, y), shoes)
    
    img.save(os.path.join(ASSETS, "player.png"))

def generate_seeds():
    """16x16 seed icons: 6 seed types."""
    img = Image.new("RGBA", (96, 16), (0, 0, 0, 0))
    
    colors = [
        (255, 200, 50),   # Yellow (common)
        (200, 80, 80),    # Red (common)
        (80, 130, 255),   # Blue (uncommon)
        (200, 100, 230),  # Purple (uncommon)
        (255, 160, 50),   # Orange (rare)
        (50, 230, 180),   # Teal (rare)
    ]
    
    for idx, color in enumerate(colors):
        base_x = idx * 16
        # Seed shape: small oval
        for y in range(4, 12):
            for x in range(4, 12):
                dx = x - 8
                dy = y - 8
                if dx*dx + dy*dy < 12:  # circular
                    r = max(0, min(255, color[0] + hash((x, y, idx)) % 20 - 10))
                    g = max(0, min(255, color[1] + hash((x, y, idx)) % 20 - 10))
                    b = max(0, min(255, color[2] + hash((x, y, idx)) % 20 - 10))
                    img.putpixel((base_x + x, y), (r, g, b, 255))
        # Highlight dot
        img.putpixel((base_x + 6, 6), (255, 255, 255, 180))
    
    img.save(os.path.join(ASSETS, "seeds.png"))

def generate_plants():
    """16x16 plant growth stages: 4 stages per plant type, 4 plant types = 64x16"""
    img = Image.new("RGBA", (64, 16), (0, 0, 0, 0))
    
    plant_colors = [
        (80, 200, 60),    # Green (common)
        (220, 80, 80),    # Red bloom
        (80, 100, 240),   # Blue bloom
        (240, 180, 60),   # Golden (rare)
    ]
    
    for plant_idx, color in enumerate(plant_colors):
        base_x = plant_idx * 16
        for stage in range(4):
            # Each stage occupies 4px horizontally
            stage_x = base_x + stage
            for y in range(16):
                # Seed in soil
                if stage == 0:
                    if y > 12:
                        img.putpixel((stage_x, y), (100, 70, 40))
                    elif y > 10:
                        c = max(0, color[0] - 60)
                        img.putpixel((stage_x, y), (c, max(0, color[1] - 40), max(0, color[2] - 40), 255))
                # Sprout
                elif stage == 1:
                    if y > 12:
                        img.putpixel((stage_x, y), (100, 70, 40))
                    elif y > 8:
                        c = max(0, color[0] - 30)
                        img.putpixel((stage_x, y), (c, color[1], max(0, color[2] - 30), 255))
                # Growing
                elif stage == 2:
                    if y > 12:
                        img.putpixel((stage_x, y), (100, 70, 40))
                    elif y > 4:
                        img.putpixel((stage_x, y), color)
                # Full bloom
                elif stage == 3:
                    if y > 12:
                        img.putpixel((stage_x, y), (100, 70, 40))
                    elif y > 3:
                        img.putpixel((stage_x, y), color)
                    if y == 5 or y == 6:
                        img.putpixel((stage_x, y), (min(255, color[0]+40), min(255, color[1]+40), min(255, color[2]+40), 255))
    
    img.save(os.path.join(ASSETS, "plants.png"))

def generate_ui():
    """UI elements: buttons, inventory slots, etc."""
    img = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    
    # Button (32x16)
    btn_bg = (60, 130, 200)
    for y in range(16):
        for x in range(32):
            if y < 2 or y > 13 or x < 2 or x > 29:
                img.putpixel((x, y), (40, 100, 170))  # border
            else:
                img.putpixel((x, y), btn_bg)
    
    # Inventory slot (32x16)
    slot_x = 32
    for y in range(16):
        for x in range(32):
            if y < 1 or y > 14 or x < 33 or x > 62:
                img.putpixel((slot_x + x - 32, y), (80, 70, 60))  # border
            else:
                img.putpixel((slot_x + x - 32, y), (50, 45, 40))  # dark bg
    
    # Coin icon (16x16)
    coin_x = 64
    for y in range(16):
        for x in range(16):
            dx = x - 8
            dy = y - 8
            if dx*dx + dy*dy < 50:
                if dx*dx + dy*dy < 40:
                    img.putpixel((coin_x + x, y), (255, 215, 0, 255))  # gold
                else:
                    img.putpixel((coin_x + x, y), (200, 170, 0, 255))  # edge
            # $ symbol
            if y == 5 and (x == 7 or x == 8):
                img.putpixel((coin_x + x, y), (180, 140, 0, 255))
            if y == 6 and x == 8:
                img.putpixel((coin_x + x, y), (180, 140, 0, 255))
            if y == 7 and (x == 7 or x == 8):
                img.putpixel((coin_x + x, y), (180, 140, 0, 255))
            if y == 8 and x == 7:
                img.putpixel((coin_x + x, y), (180, 140, 0, 255))
            if y == 9 and (x == 7 or x == 8):
                img.putpixel((coin_x + x, y), (180, 140, 0, 255))
    
    # Heart icon (16x16)
    heart_x = 80
    for y in range(16):
        for x in range(16):
            dx = x - 8
            dy = y - 8
            # Heart shape
            hx = abs(dx)
            hy = dy
            if (hx*hx + (hy-2)*(hy-2) < 16) or (abs(dx) < 4 and hy > 2 and hy < 8):
                img.putpixel((heart_x + x, y), (255, 80, 80, 255))
    
    # Empty slot highlight (16x16)
    hl_x = 96
    for y in range(16):
        for x in range(16):
            if y < 1 or y > 14 or x < 1 or x > 14:
                img.putpixel((hl_x + x, y), (120, 110, 90, 255))
            else:
                img.putpixel((hl_x + x, y), (60, 55, 45, 255))
    
    # Crossbreed icon (16x16)
    cb_x = 112
    for y in range(16):
        for x in range(16):
            if x == 8 or y == 8:
                img.putpixel((cb_x + x, y), (200, 100, 200, 255))  # purple cross
            else:
                img.putpixel((cb_x + x, y), (0, 0, 0, 0))
    
    img.save(os.path.join(ASSETS, "ui.png"))

if __name__ == "__main__":
    os.makedirs(ASSETS, exist_ok=True)
    generate_icon()
    generate_tiles()
    generate_player()
    generate_seeds()
    generate_plants()
    generate_ui()
    print("All assets generated.")