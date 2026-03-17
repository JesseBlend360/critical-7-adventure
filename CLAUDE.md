# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Critical 7 is a top-down 2D AI strategy adventure game built in Godot 4.5. The player walks around an office and talks to NPCs about AI transformation challenges. Target platform is web (HTML5 export via Godot's Compatibility Renderer).

## Build & Run Commands

```bash
# Run the game in Godot editor
godot --path . --editor

# Run the game directly
godot --path .

# Export for web (after configuring export preset)
godot --headless --export-release "Web" build/index.html
```

## Architecture

### Autoload Singletons (scripts/)
- `GameState` - Central state store: scores, flags, budget, timeline, talked_to tracking
- `DecisionManager` - Decision logic: loads decisions.json, calculates costs/effects, endings
- `DialogueManager` - Conversation flow: loads JSON, evaluates conditions, emits signals
- `GameManager` - Legacy singleton for dialogue_active state
- `FloatingTextManager` - Spawns floating score text above the player

### Scene Structure
- `scenes/main.tscn` - Main game scene containing map, NPCs, player, HUD, UI, BossFight, ChipCompanion, Terminal
- `scenes/player.tscn` - CharacterBody2D with AnimatedSprite2D, BounceAnimator, CharacterAnimator
- `scenes/npc.tscn` - RigidBody2D NPC with AnimatedSprite2D, BounceAnimator, CharacterAnimator, interaction zone
- `scenes/chip_companion.tscn` - In-world Node2D CHIP companion that follows player (replaces old HUD chip.tscn)
- `scenes/interactable.tscn` - Generic interactable object (breakable, container, readable, switch)
- `scenes/ui/dialogue_box.tscn` - CanvasLayer dialogue UI with portraits, RichTextLabel, choice buttons
- `scenes/ui/hud.tscn` - Pixel art HUD with NinePatch panels, coin/hourglass icons, budget bar, week counter, Critical 7 score indicators
- `scenes/ui/status_screen.tscn` - Tab menu showing Critical 7 scores
- `scenes/ui/ending_screen.tscn` - End game summary with narrative
- `scenes/terminal.tscn` - Computer terminal for sending company-wide messages
- `scenes/door.tscn` - Interactable door with lock support

### TileMap System (Godot 4.3+)
- `p-assets/tilesets/modern-office-tileset.tres` - TileSet resource (16x16 tiles)
- `OfficeMap` - A single TileMapLayer node directly in `main.tscn` (scaled 3x)
- Maps are painted in the Godot editor (not generated at runtime)

### Script Responsibilities
- `scripts/player.gd` - 8-direction movement, feeds direction to CharacterAnimator, connects to DialogueManager signals
- `scripts/npc.gd` - RigidBody2D physics, wandering with bounds, feeds direction to CharacterAnimator, boss fight support
- `scripts/character_animator.gd` - Builds SpriteFrames at runtime from character sprite sheets (16x32 frames, shared layout)
- `scripts/dialogue_box.gd` - Portraits, RichTextLabel with BBCode, punctuation-aware typewriter, locked choices
- `scripts/dialogue_manager.gd` - Loads dialogue JSON, manages conversation state, handles `adds_decision`
- `scripts/game_state.gd` - Tracks scores, flags, budget, timeline; evaluates conditions; applies effects
- `scripts/decision_manager.gd` - Loads decisions.json, applies costs/effects, calculates endings with boss fight
- `scripts/hud.gd` - Pixel art HUD: budget bar with coin icon, week display with hourglass, 7 score indicators color-coded by health
- `scripts/status_screen.gd` - Shows Critical 7 scores, trajectory text, toggles on Tab key
- `scripts/chip_companion.gd` - In-world Navi-like companion: follows player, flits, states (idle/talking/excited/alarmed), speech bubbles
- `scripts/ending_screen.gd` - Shows ending narrative based on calculated tier, boss fight results
- `scripts/bounce_animator.gd` - Reusable component for idle bob, walk bounce, and shadows (supports both Sprite2D and AnimatedSprite2D)
- `scripts/boss_fight.gd` - "The Board Presentation" end-game sequence with action budget and objectives
- `scripts/interactable.gd` - Generic interactable: breakable boxes, readables, containers, switches
- `scripts/door.gd` - Interactable door with optional flag-based lock
- `scripts/terminal.gd` - Computer terminal: sends company-wide messages via DecisionManager, Morgan's comm plan flag switches prepared/unprepared variants

### Terminal System
- Physical computer in the office for sending company-wide messages
- 5 messages, each with prepared (morgan_comm_plan) and unprepared decision variants
- Messages defined in `data/terminal_messages.json`, decisions in `data/decisions.json` (terminal_* IDs)
- CHIP reacts differently to prepared vs unprepared messages
- Morgan has dialogue reaction when messages sent without her comm plan

### Dialogue System
- Per-NPC JSON files in `data/dialogue/{npc_id}.json`
- Node-based structure with conversations, nodes, choices
- `conditions` - Hidden choices (completely removed if unmet)
- `requires` - Visible locked choices (shown grayed out with requirements)
- `adds_decision` - Triggers a decision from decisions.json when choice selected
- Supports effects (score changes, set/unset flags)
- Supports BBCode in text: `[shake]`, `[wave]`, `[color=red]` etc.
- First meeting vs return visit triggers

### Decision System
- Decisions defined in `data/decisions.json` (29 decisions)
- Each has: cost (budget, time), impact (7 scores), prerequisites, excludes
- Costs are visible to player; score impacts are hidden until ending
- Triggered via `adds_decision` field in dialogue choices
- Categories: strategy, data, technical, talent, change, trust, innovation

### Boss Fight System
- Triggers when week > 16 (intercepts normal game_over)
- Action budget calculated from: NPCs talked to, decisions made, high scores, secrets found
- ~9 objectives tied to NPCs, each with quality based on relevant score
- Player runs around office completing objectives until actions run out
- Results feed into ending calculation

### Character Animation System
- `CharacterAnimator` builds `SpriteFrames` at runtime from a single sprite sheet PNG
- All character sheets share the same layout: row 0 = idle (4 directions), row 1 = walk (6 frames x 4 directions)
- Left-facing = right-facing animation with `flip_h = true`
- Player: sprite_sheet set via export in `player.tscn`
- NPCs: sprite_sheet forwarded from `npc_sprite` export in `npc.gd._ready()`
- `BounceAnimator` adds subtle movement bob and shadow (defaults reduced: idle_bob=0, move_bob=0.5, rotation=0)

### Portrait System
- 96x96 portraits stored in `assets/portraits/{character_id}.png`
- Loaded by `dialogue_box.gd._load_portrait()` with cache
- Player portrait key: `"player"` → `assets/portraits/player.png`
- NPC portrait key: npc_id (e.g., `"sage"`) → `assets/portraits/sage.png`
- Falls back to generated colored placeholder if file not found
- Portrait pulses on each new dialogue line

### HUD System
- NinePatchRect panels using `assets/ui/panel_frame.png` (extracted from `p-assets/sprites/modern_ui.png`)
- Budget: coin icon + label + styled ProgressBar (color changes at 20%/40% thresholds)
- Weeks: hourglass icon + label (color changes at 75%/90% thresholds)
- Critical 7 indicators: 7 small `panel_small.png` icons modulated green/yellow/red by score value, labeled S/D/T/I/C/Ta/Tr

### Data Files
- `data/decisions.json` - 30 major project decisions
- `data/chip_lines.json` - CHIP contextual dialogue by category
- `data/endings.json` - 5 ending tiers with narratives (including boss fight variants)
- `data/terminal_messages.json` - 5 terminal messages with prepared/unprepared decision mappings
- `data/dialogue/sage.json` - Strategy consultant (Strategy score champion)
- `data/dialogue/delta.json` - Data engineer (Data score champion)
- `data/dialogue/nova.json` - ML engineer (Innovation score champion)
- `data/dialogue/harry.json` - CEO (Trust score champion, trust-based branching)
- `data/dialogue/rex.json` - Platform architect (Technical score champion)
- `data/dialogue/morgan.json` - Internal comms lead (Change score champion)
- `data/dialogue/casey.json` - L&D manager (Talent score champion)

## NPCs

| NPC | Score | Role | Personality |
|-----|-------|------|-------------|
| Sage | Strategy | Strategy Consultant | Measured, analytical |
| Delta | Data | Data Engineer | Blunt, frustrated |
| Nova | Innovation | ML Engineer | Energetic, chaotic |
| Harry | Trust | CEO & Founder, 37 years | Skeptical, direct |
| Rex | Technical | Platform Architect, 8 years | Pragmatic, exhausted |
| Morgan | Change | Internal Comms Lead, 5 years | Empathetic, overwhelmed |
| Casey | Talent | L&D Manager, 3 years | Optimistic, realistic |

## Key Mechanics

- Player movement: 8 directions at ~200 px/sec, disabled during dialogue
- NPC interaction: Area2D detects player proximity, shows "[space]" prompt
- NPC physics: RigidBody2D allows pushing NPCs, they wander tile-by-tile within bounds
- Dialogue flow: Branching conversations with choices, conditions, and effects
- Budget: $750K starting, spent by decisions
- Timeline: 16 weeks, advanced by decisions
- Boss Fight: "The Board Presentation" — action budget system at week 16+
- Endings: 5 tiers (catastrophic, partial_failure, mixed, success, exceptional)
- CHIP: In-world companion that follows player, gives contextual advice, reacts to events
- Terminal: Computer for sending company-wide messages (5 messages, prepared/unprepared variants based on Morgan's comm plan)
- Interactables: Breakable boxes (score loot), readables (lore), containers (flags), switches
- Animation: CharacterAnimator drives walk/idle sprite animations from sprite sheets; BounceAnimator adds subtle bob and shadows
- Portraits: 96x96 pixel art portraits in `assets/portraits/` — fantasy-office mashup (elf consultant, ogre data engineer, cat ML engineer, etc.)
- Sprite Sheets: 896x640 character sheets in `p-assets/sprites/characters/`, all share same frame layout (see `docs/characters.md`)

## Controls

| Action | Keys |
|--------|------|
| Move | WASD / Arrow keys |
| Interact | Space / E |
| Select choice | 1 / 2 / 3 or click |
| Status screen | Tab |

## State System

GameState tracks:
- `scores`: strategy, data, technical, innovation, change, talent, trust (all int)
- `budget`: Current remaining budget (starts at 750000)
- `current_week`: Current week number (starts at 1)
- `flags`: Array of string flags set by dialogue
- `talked_to`: Array of NPC IDs the player has conversed with
- `decisions_made`: Array of decision IDs
- `decision_log`: Array of dictionaries with decision details
- `dialogue_history`: Last visited node per NPC

Conditions can check: talked_to, not_talked_to, flags, not_flags, score_min, score_max

Game flow: budget <= 0 → immediate ending | current_week > 16 → boss fight → ending

## Key Patterns
- **Interaction**: All interactables use Area2D → `player.set_nearby_npc(self)` + `interact()` method
- **Signals**: GameState emits, UI listens
- **Data-driven**: Dialogue/decisions/CHIP lines are JSON
- **BounceAnimator**: Attach to any animated object for idle/walk animations
