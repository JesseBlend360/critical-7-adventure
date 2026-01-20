# Critical 7 — UI System Documentation

**Last Updated:** 2026-01-19

---

## Overview

The UI system uses pixel art sprites from LimeZu's Modern UI asset pack (`p-assets/sprites/modern_ui.png`). All UI elements use **NinePatchRect** for scalable panels and **StyleBoxTexture** for themed buttons.

---

## Asset Files

| File | Purpose |
|------|---------|
| `p-assets/sprites/modern_ui.png` | Main UI spritesheet (panels, buttons, bars) |
| `p-assets/sprites/modern_office.png` | Office furniture sprites |
| `assets/fonts/Jersey15-Regular.ttf` | Primary pixel font |
| `assets/themes/dialogue_theme.tres` | Button theme for dialogue choices |

---

## UI Scenes

### 1. Dialogue Box (`scenes/ui/dialogue_box.tscn`)

**Script:** `scripts/dialogue_box.gd`

Two-panel dialogue system:
- **DialoguePanel** (bottom) - Shows NPC name, dialogue text, advance indicator
- **ChoicesPanel** (center popup) - Shows player choices with keyboard navigation

**Structure:**
```
DialogueBox (CanvasLayer, layer=10)
├── DialoguePanel (NinePatchRect, anchored bottom)
│   └── MarginContainer
│       └── VBoxContainer
│           ├── NameLabel (font_size=42)
│           ├── TextLabel (font_size=32, autowrap)
│           └── AdvanceIndicator (font_size=24)
└── ChoicesPanel (NinePatchRect, centered popup)
    └── MarginContainer
        └── VBoxContainer
            ├── ChoicesTitle
            ├── ChoicesContainer (VBoxContainer with theme)
            │   ├── Choice1-3 (Buttons)
            └── HintLabel
```

**NinePatchRect Settings:**
- `texture`: modern_ui.png
- `region_rect`: Rect2(0, 0, 48, 48) — main panel sprite
- `patch_margin_*`: 32 (doubled from 16 for pixel scale)

**Input Handling:**
- Space/E/Enter: Advance dialogue or open choices
- Arrow keys: Navigate choices (with focus highlight)
- 1/2/3: Direct choice selection
- ESC: Close dialogue or go back from choices

### 2. HUD (`scenes/ui/hud.tscn`)

**Script:** `scripts/hud.gd`

Minimal always-visible status display.

**Structure:**
```
HUD (CanvasLayer, layer=5)
├── TopBar (HBoxContainer)
│   ├── BudgetContainer (VBoxContainer)
│   │   ├── BudgetLabel ("$750K / $750K")
│   │   └── BudgetBar (ProgressBar)
│   └── WeekContainer (VBoxContainer)
│       └── WeekLabel ("Week 1 / 16")
└── CHIP (instanced from chip.tscn)
```

**Color Coding:**
- Budget bar: Green (>40%), Yellow (20-40%), Red (<20%)
- Week label: White (normal), Yellow (>75%), Red (>90%)

**TODO:** Replace ProgressBar with pixel art bar using sprites from modern_ui.png

### 3. Status Screen (`scenes/ui/status_screen.tscn`)

**Script:** `scripts/status_screen.gd`

Full project status panel (Tab to toggle).

Shows:
- Critical 7 scores with progress bars
- Budget remaining
- Current week / total weeks
- Trajectory text summary
- Decision count

**Input:**
- Tab: Toggle visibility
- ESC: Close

### 4. Ending Screen (`scenes/ui/ending_screen.tscn`)

**Script:** `scripts/ending_screen.gd`

End-of-game summary showing final scores and narrative.

---

## Theme System

### dialogue_theme.tres

Button styling for choice buttons.

**StyleBoxTexture Definitions:**

| Style | Region (x, y, w, h) | Purpose |
|-------|---------------------|---------|
| normal | (18, 21, 11, 9) | Default button state |
| hover | (51, 80, 42, 16) | Mouse hover state |
| focus | (51, 80, 42, 16) | Keyboard focus state |
| pressed | (60, 14, 24, 21) | Button pressed |
| disabled | (60, 13, 24, 22) | Locked/unavailable choice |

All StyleBoxTexture use `texture_margin_*: 1.0` for 9-slice behavior.

---

## Container Pattern

All UI panels follow this hierarchy for proper layout:

```
NinePatchRect (visual panel)
└── MarginContainer (inner padding)
    └── VBoxContainer/HBoxContainer (content layout)
        └── [Content nodes]
```

**Why this pattern:**
1. NinePatchRect provides the scalable visual border
2. MarginContainer creates padding inside the panel
3. VBox/HBoxContainer handles content layout with size_flags

**Key Settings:**
- MarginContainer children need `layout_mode = 2` (container sizing)
- Labels with autowrap need `custom_minimum_size` for height
- Use `size_flags_vertical = 3` (expand+fill) for flexible content

---

## Input Actions

| Action | Keys | Purpose |
|--------|------|---------|
| `interact` | Space, E | Advance dialogue, interact with NPCs |
| `cancel` | ESC | Close UI, go back |
| `ui_up/down` | Arrow keys | Navigate choices |
| `ui_accept` | Enter | Confirm selection |
| `ui_cancel` | ESC | Built-in Godot cancel |

---

## Sprite Regions Reference (modern_ui.png)

### Panels
- Main panel: (0, 0, 48, 48)

### Buttons
- Normal: (18, 21, 11, 9)
- Hover/Focus: (51, 80, 42, 16)
- Pressed: (60, 14, 24, 21)
- Disabled: (60, 13, 24, 22)

### Progress Bars (TODO)
The spritesheet contains progress bar elements:
- Green filled bars (multiple sizes)
- Brown/empty bars
- Yellow/gold variant bars
- Left cap, middle segment, right cap pieces

---

## Implementation Notes

### Pixel Scaling
Game sprites use 3x scale. UI textures need:
- `patch_margin_*: 32` (instead of 16) on NinePatchRect
- `texture_margin_*: 1.0` on StyleBoxTexture (texture-relative)
- Project setting: `textures/canvas_textures/default_texture_filter = 0` (Nearest)

### CanvasLayer Ordering
| Layer | UI Element |
|-------|------------|
| 5 | HUD |
| 10 | DialogueBox |

### Signal Flow
```
GameState.budget_changed → HUD._on_budget_changed
GameState.week_changed → HUD._on_week_changed
DialogueManager.dialogue_started → DialogueBox._on_dialogue_started
DialogueManager.node_displayed → DialogueBox._on_node_displayed
DialogueManager.choices_presented → DialogueBox._on_choices_presented
DialogueManager.dialogue_ended → DialogueBox._on_dialogue_ended
```

---

## Future Work

- [ ] Replace ProgressBar with pixel art budget bar
- [ ] Add week progress bar with pixel art
- [ ] Create tooltip system for score explanations
- [ ] Add decision log UI
- [ ] Animate panel open/close
- [ ] Add sound effects for UI interactions
