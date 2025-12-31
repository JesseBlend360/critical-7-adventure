# Critical 7 — Prototype PRD (v0.1)

**Status: COMPLETED**

---

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

- [x] **FR-1.1** Player moves in 8 directions using WASD or arrow keys
- [x] **FR-1.2** Player has idle and walking animations (or static sprite for prototype)
- [x] **FR-1.3** Player cannot walk through walls, furniture, or NPCs
- [x] **FR-1.4** Camera follows player, centered on screen
- [x] **FR-1.5** Movement speed: ~200 pixels/second (tunable)

### 2. Office Environment

- [x] **FR-2.1** Single-room office map for prototype (expandable later)
- [x] **FR-2.2** Map includes:
  - Walls/boundaries
  - Desks (collision obstacles)
  - Floor tiles
  - Door (non-functional for prototype, visual only)
  - 2-3 decorative elements (plants, chairs, whiteboard)
- [x] **FR-2.3** Map size: approximately 800x600 to 1200x800 pixels
- [x] **FR-2.4** Top-down perspective (straight down, no angle for prototype)
- [x] **FR-2.5** Collision shapes on all solid objects

### 3. NPCs

- [x] **FR-3.1** Prototype includes 2-3 NPCs placed in the office
- [x] **FR-3.2** NPCs are stationary (no pathfinding for prototype)
  - **BONUS:** NPCs now have tile-based wandering behavior
  - **BONUS:** NPCs are pushable (RigidBody2D physics)
- [x] **FR-3.3** NPCs have:
  - Static sprite
  - Collision shape (player can't walk through them)
  - Interaction zone (Area2D) that detects player proximity
- [x] **FR-3.4** Visual indicator when player is in range to talk (e.g., "E" prompt or highlight)

### 4. Dialogue System

- [x] **FR-4.1** Press interaction key (Space or E) when near NPC to start dialogue
- [x] **FR-4.2** Dialogue box appears at bottom of screen
- [x] **FR-4.3** Dialogue box displays:
  - NPC name
  - Current line of text
  - Visual indicator to advance (e.g., "▼" or "Press Space")
- [x] **FR-4.4** Press interaction key to advance to next line
- [x] **FR-4.5** Dialogue ends when all lines are exhausted, box closes
- [x] **FR-4.6** Player movement disabled during dialogue
- [x] **FR-4.7** Dialogue content loaded from external data file (JSON)

**BONUS - Advanced Dialogue (Added in v0.1.5):**
- [x] Branching dialogue with choices
- [x] Conditions on choices (talked_to, flags, score checks)
- [x] Effects from choices (score changes, flag setting)
- [x] First meeting vs return visit conversations
- [x] Per-NPC dialogue JSON files

### 5. Animation System (BONUS)

- [x] **BounceAnimator** component for characters
- [x] Idle bob animation
- [x] Walking bounce with side-to-side hop
- [x] Rotation twist during movement
- [x] Procedural shadow generation

---

## Acceptance Criteria - COMPLETED

- [x] Player can move around the office in 8 directions
- [x] Player collides with walls and cannot exit the room
- [x] Player collides with furniture and NPCs
- [x] At least 2 NPCs are placed in the office (3 implemented: Sage, Delta, Nova)
- [x] Walking near an NPC shows an interaction prompt
- [x] Pressing interact key opens dialogue box
- [x] Dialogue box shows NPC name and text
- [x] Pressing interact key advances dialogue
- [x] Dialogue box closes after final line
- [x] Player cannot move during dialogue
- [x] Player can move again after dialogue ends
- [ ] Game runs in browser (HTML5 export) - **NOT TESTED YET**

---

## What Was Built

### Autoload Singletons
- `GameManager` - Legacy dialogue state
- `GameState` - Full state management (scores, flags, talked_to, conditions)
- `DialogueManager` - Conversation flow, JSON loading, signals

### Scenes
- `scenes/main.tscn` - Main game with TileMap, NPCs, player, UI
- `scenes/player.tscn` - CharacterBody2D with BounceAnimator
- `scenes/npc.tscn` - RigidBody2D with wandering, interaction zone, BounceAnimator
- `scenes/ui/dialogue_box.tscn` - Dialogue UI with choice buttons

### Scripts
- `scripts/player.gd` - 8-direction movement, DialogueManager integration
- `scripts/npc.gd` - RigidBody2D physics, tile-based wandering, interaction
- `scripts/dialogue_box.gd` - Signal-based UI, choice handling
- `scripts/dialogue_manager.gd` - Conversation flow, condition evaluation
- `scripts/game_state.gd` - State tracking, effects application
- `scripts/bounce_animator.gd` - Reusable animation component

### Data
- `data/dialogue/sage.json` - Strategy consultant (branching)
- `data/dialogue/delta.json` - Data engineer (branching)
- `data/dialogue/nova.json` - ML engineer (branching)

---

## Superseded By

**[PRD v0.2 - Decisions & UI](prd_v0.2_decisions.md)**
