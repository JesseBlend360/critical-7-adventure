# Critical 7 — Prototype PRD

## Overview

**Project:** Critical 7 - AI Strategy Adventure Game  
**Version:** 0.1 (Prototype)  
**Engine:** Godot 4.x (Compatibility Renderer for web export)  
**Target Platform:** Web (embedded widget on company website)  
**Development Tool:** Claude Code

---

## Prototype Scope

This prototype validates the core gameplay loop: **walk around an office and talk to people**. No scoring, no minigames, no boss fight yet — just movement, environment, and dialogue.

### What's IN scope
- Top-down player movement
- Office environment with collision
- NPC characters that can be approached
- Dialogue system with text display
- Basic interaction (press key to talk)

### What's OUT of scope (for now)
- Critical 7 scoring system
- Minigames
- CEO check-ins / expectation management
- Final boss battle
- Sound/music
- Save system
- Sprite stacking / pseudo-3D (flat 2D for prototype)

---

## Functional Requirements

### 1. Player Movement

**FR-1.1** Player moves in 8 directions using WASD or arrow keys  
**FR-1.2** Player has idle and walking animations (or static sprite for prototype)  
**FR-1.3** Player cannot walk through walls, furniture, or NPCs  
**FR-1.4** Camera follows player, centered on screen  
**FR-1.5** Movement speed: ~200 pixels/second (tunable)

### 2. Office Environment

**FR-2.1** Single-room office map for prototype (expandable later)  
**FR-2.2** Map includes:
- Walls/boundaries
- Desks (collision obstacles)
- Floor tiles
- Door (non-functional for prototype, visual only)
- 2-3 decorative elements (plants, chairs, whiteboard)

**FR-2.3** Map size: approximately 800x600 to 1200x800 pixels  
**FR-2.4** Top-down perspective (straight down, no angle for prototype)  
**FR-2.5** Collision shapes on all solid objects

### 3. NPCs

**FR-3.1** Prototype includes 2-3 NPCs placed in the office  
**FR-3.2** NPCs are stationary (no pathfinding for prototype)  
**FR-3.3** NPCs have:
- Static sprite
- Collision shape (player can't walk through them)
- Interaction zone (Area2D) that detects player proximity

**FR-3.4** Visual indicator when player is in range to talk (e.g., "E" prompt or highlight)

### 4. Dialogue System

**FR-4.1** Press interaction key (Space or E) when near NPC to start dialogue  
**FR-4.2** Dialogue box appears at bottom of screen  
**FR-4.3** Dialogue box displays:
- NPC name
- Current line of text
- Visual indicator to advance (e.g., "▼" or "Press Space")

**FR-4.4** Press interaction key to advance to next line  
**FR-4.5** Dialogue ends when all lines are exhausted, box closes  
**FR-4.6** Player movement disabled during dialogue  
**FR-4.7** Dialogue content loaded from external data file (JSON)

### 5. Interaction Flow

```
[Player walks around]
        |
        v
[Player enters NPC interaction zone]
        |
        v
[UI prompt appears: "Press E to talk"]
        |
        v
[Player presses E]
        |
        v
[Player movement disabled]
[Dialogue box appears]
[First line of dialogue displayed]
        |
        v
[Player presses E to advance]
        |
        v
[Next line displayed, or dialogue ends]
        |
        v
[Dialogue box closes]
[Player movement re-enabled]
```

---

## Technical Specifications

### Project Structure

```
critical7/
├── project.godot
├── scenes/
│   ├── main.tscn              # Main game scene
│   ├── player.tscn            # Player scene (CharacterBody2D)
│   ├── npc.tscn               # Base NPC scene (reusable)
│   ├── office_map.tscn        # TileMap or Node2D with office layout
│   └── ui/
│       └── dialogue_box.tscn  # Dialogue UI (CanvasLayer)
├── scripts/
│   ├── player.gd              # Player movement + interaction
│   ├── npc.gd                 # NPC interaction zone + dialogue trigger
│   ├── dialogue_box.gd        # Dialogue display logic
│   └── game_manager.gd        # Global state (autoload singleton)
├── assets/
│   ├── sprites/
│   │   ├── player.png
│   │   ├── npc_1.png
│   │   ├── npc_2.png
│   │   └── office_tiles.png
│   └── fonts/
│       └── dialogue_font.ttf  # Or use Godot default
└── data/
    └── dialogue.json          # All NPC dialogue content
```

### Scene Hierarchy

**main.tscn:**
```
Main (Node2D)
├── OfficeMap (TileMap or Node2D)
│   ├── Walls (StaticBody2D + CollisionShape2D)
│   ├── Furniture (StaticBody2D nodes)
│   └── Decorations (Sprite2D nodes, no collision)
├── NPCs (Node2D)
│   ├── NPC_Sage (npc.tscn instance)
│   ├── NPC_Delta (npc.tscn instance)
│   └── NPC_Nova (npc.tscn instance)
├── Player (player.tscn instance)
├── Camera2D (attached to Player or separate with follow)
└── UI (CanvasLayer)
    └── DialogueBox (dialogue_box.tscn instance)
```

### Dialogue Data Format

**data/dialogue.json:**
```json
{
  "sage": {
    "name": "Sage",
    "lines": [
      "Welcome to the AI Initiative.",
      "Before we build anything, we need to understand the business case.",
      "What problem are we really trying to solve?"
    ]
  },
  "delta": {
    "name": "Delta",
    "lines": [
	  "Ah, you're the new lead.",
	  "I hope you're ready to talk about data quality.",
      "Because nobody else around here wants to."
    ]
  },
  "nova": {
    "name": "Nova",
    "lines": [
	  "Hey! I've been prototyping something cool.",
	  "Check this out — it's not production-ready but...",
	  "Actually, nothing I make is production-ready. That's my brand."
    ]
  }
}
```

### Key Scripts Overview

**player.gd:**
- Extends CharacterBody2D
- Handles input for 8-direction movement
- Exports `speed` variable (default 200)
- Has `can_move` bool (set to false during dialogue)
- Detects interaction input, signals to nearby NPC

**npc.gd:**
- Extends CharacterBody2D (or StaticBody2D)
- Has child Area2D for interaction zone
- Exports `npc_id` string (matches key in dialogue.json)
- Signals when player enters/exits zone
- On interaction, tells DialogueBox to start conversation

**dialogue_box.gd:**
- Extends Control (inside CanvasLayer)
- `start_dialogue(npc_id: String)` — loads lines, shows box
- `advance()` — shows next line or closes
- Signals `dialogue_started` and `dialogue_ended`
- References JSON dialogue data

**game_manager.gd (Autoload):**
- Holds reference to current dialogue state
- Tracks `dialogue_active` bool
- Future: will hold Critical 7 scores

---

## Art Style (Prototype)

For the prototype, we can use:

**Option A: Placeholder shapes**
- Player: colored rectangle or circle
- NPCs: different colored rectangles
- Walls: gray rectangles
- Floor: single color background

**Option B: Simple pixel art**
- 16x16 or 32x32 character sprites
- Basic office tileset (can find free assets or generate)
- Top-down perspective

**Recommendation:** Start with Option A (shapes) to validate mechanics, then add art.

---

## Controls

| Action | Key(s) |
|--------|--------|
| Move Up | W / ↑ |
| Move Down | S / ↓ |
| Move Left | A / ← |
| Move Right | D / → |
| Interact / Advance Dialogue | E / Space |

---

## Acceptance Criteria

The prototype is complete when:

- [ ] Player can move around the office in 8 directions
- [ ] Player collides with walls and cannot exit the room
- [ ] Player collides with furniture and NPCs
- [ ] At least 2 NPCs are placed in the office
- [ ] Walking near an NPC shows an interaction prompt
- [ ] Pressing interact key opens dialogue box
- [ ] Dialogue box shows NPC name and text
- [ ] Pressing interact key advances dialogue
- [ ] Dialogue box closes after final line
- [ ] Player cannot move during dialogue
- [ ] Player can move again after dialogue ends
- [ ] Game runs in browser (HTML5 export)

---

## Future Iterations (Out of Scope Now)

**v0.2 — Scoring & Choices**
- Add Critical 7 score tracking
- Dialogue choices that affect scores
- UI showing current scores

**v0.3 — Full Office**
- Multiple rooms/floors
- All 7 NPCs placed
- Room transitions

**v0.4 — CEO Check-ins**
- Timed CEO encounters
- Expectation management mechanic

**v0.5 — Minigames**
- One minigame per NPC

**v0.6 — Boss Battle**
- Final confrontation
- Score-based battle simulation

**v1.0 — Polish**
- Full art assets
- Sound/music
- Animations
- Web embed optimization

---

## Open Questions

1. **Art style decision:** Placeholder shapes vs. simple pixel art for prototype?
2. **Office layout:** Single open room or L-shaped with visual interest?
3. **Dialogue pacing:** Typewriter effect (text appears letter by letter) or instant?
4. **NPC facing:** Should NPCs turn to face player when talking?

---

## Next Steps

1. Create Godot project with Compatibility renderer
2. Implement player movement script
3. Build simple office map with collision
4. Create NPC scene with interaction zone
5. Build dialogue box UI
6. Wire everything together
7. Test HTML5 export
8. Iterate on feel and pacing
