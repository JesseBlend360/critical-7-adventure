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

### Scene Structure
- `scenes/main.tscn` - Main game scene containing map, NPCs, player, HUD, and UI
- `scenes/player.tscn` - CharacterBody2D with movement and BounceAnimator
- `scenes/npc.tscn` - RigidBody2D NPC with interaction zone and BounceAnimator
- `scenes/chip.tscn` - CHIP companion sprite with AnimationPlayer
- `scenes/ui/dialogue_box.tscn` - CanvasLayer dialogue UI with choice buttons
- `scenes/ui/hud.tscn` - Always-visible budget bar and week counter
- `scenes/ui/status_screen.tscn` - Tab menu showing Critical 7 scores
- `scenes/ui/ending_screen.tscn` - End game summary with narrative

### TileMap System (Godot 4.3+)
- `assets/sprites/Tilemap/office_tileset.tres` - TileSet resource (Kenney Tiny Dungeon, 16x16 tiles)
- `OfficeMap` - A single TileMapLayer node directly in `main.tscn` (scaled 3x)
- Maps are painted in the Godot editor (not generated at runtime)

### Script Responsibilities
- `scripts/player.gd` - 8-direction movement, connects to DialogueManager signals
- `scripts/npc.gd` - RigidBody2D physics, wandering behavior, calls DialogueManager.start_conversation()
- `scripts/dialogue_box.gd` - Shows text and choices, displays locked choices with requirements
- `scripts/dialogue_manager.gd` - Loads dialogue JSON, manages conversation state, handles `adds_decision`
- `scripts/game_state.gd` - Tracks scores, flags, budget, timeline; evaluates conditions; applies effects
- `scripts/decision_manager.gd` - Loads decisions.json, applies costs/effects, calculates endings
- `scripts/hud.gd` - Updates budget bar and week display from GameState signals
- `scripts/status_screen.gd` - Shows Critical 7 scores, trajectory text, toggles on Tab key
- `scripts/chip.gd` - Contextual commentary based on game state (budget, scores, idle)
- `scripts/ending_screen.gd` - Shows ending narrative based on calculated tier
- `scripts/bounce_animator.gd` - Reusable component for idle bob and walk bounce animations

### Dialogue System
- Per-NPC JSON files in `data/dialogue/{npc_id}.json`
- Node-based structure with conversations, nodes, choices
- `conditions` - Hidden choices (completely removed if unmet)
- `requires` - Visible locked choices (shown grayed out with requirements)
- `adds_decision` - Triggers a decision from decisions.json when choice selected
- Supports effects (score changes, set/unset flags)
- First meeting vs return visit triggers

### Decision System
- Decisions defined in `data/decisions.json` (20 decisions)
- Each has: cost (budget, time), impact (7 scores), prerequisites, excludes
- Costs are visible to player; score impacts are hidden until ending
- Triggered via `adds_decision` field in dialogue choices
- Categories: scoping, data, technical, talent, political

### Data Files
- `data/decisions.json` - 20 major project decisions
- `data/chip_lines.json` - CHIP contextual dialogue by category
- `data/endings.json` - 5 ending tiers with narratives
- `data/dialogue/sage.json` - Strategy consultant dialogue
- `data/dialogue/delta.json` - Data engineer dialogue
- `data/dialogue/nova.json` - ML engineer dialogue
- `data/dialogue/harry.json` - CEO dialogue (trust-based branching)

## Key Mechanics

- Player movement: 8 directions at ~200 px/sec, disabled during dialogue
- NPC interaction: Area2D detects player proximity, shows "[space]" prompt
- NPC physics: RigidBody2D allows pushing NPCs, they wander tile-by-tile
- Dialogue flow: Branching conversations with choices, conditions, and effects
- Budget: $750K starting, spent by decisions
- Timeline: 16 weeks, advanced by decisions
- Endings: 5 tiers (catastrophic, partial_failure, mixed, success, exceptional)
- CHIP: Contextual commentary triggered by budget, scores, idle time, milestones
- Animation: BounceAnimator provides idle bob, walk bounce, rotation, and shadows

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

Game ends when: budget <= 0 or current_week > 16
