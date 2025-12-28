# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Critical 7 is a top-down 2D AI strategy adventure game built in Godot 4.5. The player walks around an office and talks to NPCs. Target platform is web (HTML5 export via Godot's Compatibility Renderer).

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

### Scene Structure
- `scenes/main.tscn` - Main game scene containing map, NPCs, player, and UI
- `scenes/player.tscn` - CharacterBody2D with movement and interaction logic
- `scenes/npc.tscn` - Reusable NPC scene with Area2D interaction zone
- `scenes/ui/dialogue_box.tscn` - CanvasLayer dialogue UI

### TileMap System (Godot 4.3+)
- `assets/sprites/Tilemap/office_tileset.tres` - TileSet resource (Kenney Tiny Dungeon, 16x16 tiles)
- `OfficeMap` - A single TileMapLayer node directly in `main.tscn` (scaled 3x)
- Maps are painted in the Godot editor (not generated at runtime)
- To edit: open `main.tscn`, select `OfficeMap`, use the TileMap bottom panel to paint

### Script Responsibilities
- `scripts/main.gd` - Main scene setup, wires NPCs to dialogue box
- `scripts/player.gd` - 8-direction movement (WASD/arrows), `can_move` flag, interaction input
- `scripts/npc.gd` - Interaction zone detection, exports `npc_id` matching dialogue.json keys
- `scripts/dialogue_box.gd` - `start_dialogue(npc_id)`, `advance()`, signals `dialogue_started`/`dialogue_ended`
- `scripts/game_manager.gd` - Autoload singleton, tracks `dialogue_active` state

### Data Files
- `data/dialogue.json` - NPC dialogue keyed by npc_id (e.g., "sage", "delta", "nova")

## Key Mechanics

- Player movement: 8 directions at ~200 px/sec, disabled during dialogue
- NPC interaction: Area2D detects player proximity, shows "[space]" prompt
- Dialogue flow: Press Space to start and advance dialogue, box closes after final line

## Controls

| Action | Keys |
|--------|------|
| Move | WASD / Arrow keys |
| Interact | Space / E |
