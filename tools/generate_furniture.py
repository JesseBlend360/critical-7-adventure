#!/usr/bin/env python3
"""Generate furniture .tscn scenes from the modern_office.png sprite sheet.

Each scene is a StaticBody2D with a Sprite2D (region from the atlas) and
a CollisionShape2D.  Decorative-only items use Node2D instead.

Sprite sheet: p-assets/sprites/modern_office.png  (256x848, 16px grid)
Texture UID:  uid://7ixcfgmls0g3
All sprites rendered at 3x scale to match the game's pixel-art style.
"""

import os, textwrap

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "scenes", "furniture")
TEX_UID = "uid://7ixcfgmls0g3"
TEX_PATH = "res://p-assets/sprites/modern_office.png"
SCALE = 3

# ── furniture catalogue ──────────────────────────────────────────────
# (name, x, y, w, h, col_w, col_h, has_collision)
#   x,y,w,h       = region rect in the sprite sheet (pixels)
#   col_w, col_h   = collision box size in *world* pixels (after 3x scale)
#   has_collision   = False for purely decorative / wall-mounted items
#
# Region rects based on visual analysis of the LimeZu Modern Office sheet.
# Verify in the Godot editor and tweak region_rect if needed.

FURNITURE = [
    # ── DESKS & TABLES ──
    ("desk_large",        0,   0,  48, 32,  132,  54, True),
    ("desk_medium",      48,   0,  32, 32,   84,  54, True),
    ("desk_small",       80,   0,  32, 32,   84,  54, True),
    ("desk_corner_l",   112,   0,  32, 32,   84,  84, True),
    ("desk_corner_r",   144,   0,  32, 32,   84,  84, True),
    ("desk_long",         0,  32,  64, 32,  180,  54, True),
    ("table_round",      64,  32,  32, 32,   72,  72, True),
    ("table_square",     96,  32,  32, 32,   84,  84, True),
    ("table_coffee",    128,  32,  32, 16,   84,  36, True),
    ("conference_table",  0,  64,  64, 32,  180,  72, True),

    # ── SEATING ──
    # (office_chair already exists as its own scene)
    ("couch_front",       0, 160,  48, 32,  132,  60, True),
    ("couch_back",       48, 160,  48, 32,  132,  60, True),
    ("couch_left",       96, 160,  32, 48,   60, 132, True),
    ("couch_right",     128, 160,  32, 48,   60, 132, True),
    ("armchair_front",  160, 160,  32, 32,   72,  60, True),
    ("armchair_back",   192, 160,  32, 32,   72,  60, True),
    ("stool",           224, 160,  16, 16,   36,  36, True),

    # ── STORAGE ──
    ("bookshelf_tall",    0, 192,  32, 48,   84,  36, True),
    ("bookshelf_wide",   32, 192,  48, 32,  132,  36, True),
    ("filing_cabinet",   80, 192,  16, 32,   42,  36, True),
    ("filing_cabinet_2", 96, 192,  16, 32,   42,  36, True),
    ("cabinet_low",     112, 192,  32, 32,   84,  48, True),
    ("locker",          144, 192,  16, 48,   42,  36, True),
    ("shelf_wall",      160, 192,  32, 16,   84,  12, True),

    # ── ELECTRONICS & EQUIPMENT ──
    ("computer_monitor",  0, 256,  16, 16,   36,  18, True),
    ("computer_setup",   16, 256,  32, 16,   84,  18, True),
    ("laptop",           48, 256,  16, 16,   36,  18, True),
    ("printer_small",    64, 256,  16, 16,   42,  36, True),
    ("printer_large",    80, 256,  32, 32,   84,  60, True),
    ("server_rack",     112, 256,  16, 48,   42,  36, True),
    ("tv_screen",       128, 256,  32, 32,   84,  12, True),
    ("projector_screen", 160, 256,  48, 32,  132,  12, True),

    # ── KITCHEN / BREAK ROOM ──
    ("water_cooler",      0, 304,  16, 32,   36,  36, True),
    ("coffee_machine",   16, 304,  16, 16,   36,  36, True),
    ("vending_machine",  32, 304,  32, 48,   84,  48, True),
    ("microwave",        64, 304,  16, 16,   42,  36, True),
    ("fridge",           80, 304,  32, 48,   84,  48, True),
    ("sink",            112, 304,  32, 32,   84,  60, True),
    ("counter_long",    144, 304,  48, 32,  132,  54, True),

    # ── PLANTS & DECOR ──
    ("plant_small",       0, 352,  16, 32,   24,  24, True),
    ("plant_medium",     16, 352,  16, 32,   30,  30, True),
    ("plant_large",      32, 352,  32, 48,   48,  36, True),
    ("plant_hanging",    64, 352,  16, 32,    0,   0, False),
    ("plant_pot_floor",  80, 352,  16, 32,   30,  30, True),
    ("rug_small",        96, 352,  32, 32,    0,   0, False),
    ("rug_large",       128, 352,  48, 32,    0,   0, False),

    # ── WALL & MISC ──
    ("whiteboard",        0, 400,  48, 32,  132,  12, True),
    ("whiteboard_small", 48, 400,  32, 32,   84,  12, True),
    ("clock",            80, 400,  16, 16,    0,   0, False),
    ("wall_frame_a",     96, 400,  16, 16,    0,   0, False),
    ("wall_frame_b",    112, 400,  32, 16,    0,   0, False),
    ("trash_can",       144, 400,  16, 16,   30,  30, True),
    ("recycling_bin",   160, 400,  16, 16,   30,  30, True),

    # ── LIGHTING ──
    ("lamp_desk",       176, 400,  16, 16,   18,  18, True),
    ("lamp_floor",      192, 400,  16, 48,   18,  18, True),

    # ── OFFICE SUPPLIES ──
    ("paper_stack",     208, 400,  16, 16,   24,  18, True),
    ("box_cardboard",   224, 400,  16, 16,   36,  36, True),
    ("box_cardboard_open", 240, 400, 16, 16, 36,  36, True),

    # ── BATHROOM ──
    ("toilet",            0, 448,  16, 32,   36,  36, True),
    ("bathroom_sink",    16, 448,  16, 32,   36,  36, True),

    # ── RECEPTION / LOBBY ──
    ("reception_desk",    0, 480,  64, 32,  180,  60, True),
    ("divider_panel",    64, 480,  16, 48,   12, 132, True),
    ("sign_board",       80, 480,  32, 48,   84,  12, True),

    # ── DARK VARIANTS (bottom half of sheet) ──
    ("desk_large_dark",   0, 528,  48, 32,  132,  54, True),
    ("desk_medium_dark", 48, 528,  32, 32,   84,  54, True),
    ("bookshelf_dark",    0, 576,  32, 48,   84,  36, True),
    ("couch_dark",        0, 624,  48, 32,  132,  60, True),
    ("filing_cabinet_dark", 48, 624, 16, 32, 42,  36, True),
    ("plant_dark",       64, 624,  16, 32,   24,  24, True),
]


def make_scene(name, rx, ry, rw, rh, col_w, col_h, has_collision):
    """Generate a .tscn string for one furniture piece."""

    sprite_h_world = rh * SCALE
    # For sprites taller than 1 tile, shift sprite up so the "base" is at origin
    sprite_offset_y = 0
    if rh > 16:
        sprite_offset_y = -((rh - 16) * SCALE) // 2

    # Collision sits near the bottom/center of the sprite
    col_offset_y = 0
    if rh > 16:
        col_offset_y = ((rh - 16) * SCALE) // 4

    if has_collision:
        load_steps = 3  # ext_resource + RectangleShape2D sub_resource
        parts = []
        parts.append(textwrap.dedent(f"""\
            [gd_scene load_steps={load_steps} format=3]

            [ext_resource type="Texture2D" uid="{TEX_UID}" path="{TEX_PATH}" id="1_tex"]

            [sub_resource type="RectangleShape2D" id="RectangleShape2D_col"]
            size = Vector2({col_w}, {col_h})

            [node name="{_pascal(name)}" type="StaticBody2D"]

            [node name="Sprite" type="Sprite2D" parent="."]
            texture_filter = 1
            scale = Vector2({SCALE}, {SCALE})
            position = Vector2(0, {sprite_offset_y})
            texture = ExtResource("1_tex")
            region_enabled = true
            region_rect = Rect2({rx}, {ry}, {rw}, {rh})

            [node name="Collision" type="CollisionShape2D" parent="."]
            position = Vector2(0, {col_offset_y})
            shape = SubResource("RectangleShape2D_col")
        """))
        return "\n".join(parts)
    else:
        # Decorative only – no collision
        parts = []
        parts.append(textwrap.dedent(f"""\
            [gd_scene load_steps=2 format=3]

            [ext_resource type="Texture2D" uid="{TEX_UID}" path="{TEX_PATH}" id="1_tex"]

            [node name="{_pascal(name)}" type="Node2D"]

            [node name="Sprite" type="Sprite2D" parent="."]
            texture_filter = 1
            scale = Vector2({SCALE}, {SCALE})
            position = Vector2(0, {sprite_offset_y})
            texture = ExtResource("1_tex")
            region_enabled = true
            region_rect = Rect2({rx}, {ry}, {rw}, {rh})
        """))
        return "\n".join(parts)


def _pascal(snake: str) -> str:
    return "".join(w.capitalize() for w in snake.split("_"))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for item in FURNITURE:
        name = item[0]
        path = os.path.join(OUT_DIR, f"{name}.tscn")
        content = make_scene(*item)
        with open(path, "w") as f:
            f.write(content)
        print(f"  ✓ {name}.tscn")
    print(f"\nGenerated {len(FURNITURE)} furniture scenes in scenes/furniture/")


if __name__ == "__main__":
    main()
