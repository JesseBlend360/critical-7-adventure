# Changelog

All notable changes to Critical 7 will be documented in this file.

## [Unreleased] - UI Polish & Furniture

### Added

#### UI Improvements
- **Pixel art dialogue system** using LimeZu's Modern UI spritesheet
  - NinePatchRect panels with 9-slice scaling for dialogue and choices
  - Two-panel system: DialoguePanel (bottom) and ChoicesPanel (center popup)
  - StyleBoxTexture theme for button states (normal, hover, focus, pressed, disabled)
  - Keyboard navigation for choices (arrow keys + focus highlight)
  - `patch_margin: 32` for proper pixel scaling

- **Cancel action** (`cancel` input mapped to ESC)
  - ESC closes dialogue when not at choice point
  - ESC goes back from choices panel to dialogue
  - ESC closes status screen

- **UI System Documentation** (`docs/ui_system.md`)
  - Comprehensive guide to UI architecture
  - Sprite region references for modern_ui.png
  - Container pattern documentation
  - Theme system documentation

#### Furniture
- **Office Chair** (`scenes/furniture/office_chair.tscn`, `scripts/office_chair.gd`)
  - RigidBody2D pushable furniture
  - Spin interaction (press E/Space when nearby)
  - 4-direction sprites that cycle during spin
  - Physics-based momentum and friction

### Changed
- **DialogueBox** refactored for two-panel system
  - Separate DialoguePanel and ChoicesPanel NinePatchRects
  - Arrow key navigation with wrap-around
  - First available choice auto-focused when panel opens
  - Space/Enter selects currently highlighted choice

- **Player** can push RigidBody2D objects
  - Uses `apply_central_force` with player's movement direction
  - Only applies force when actively moving

- **StatusScreen** responds to `cancel` action

---

## [Unreleased] - PRD v0.2: Decisions & Game Loop

### Added

#### Core Systems
- **Budget & Timeline tracking** in GameState
  - `budget`: $750K starting, spent by decisions
  - `current_week`: 16-week project timeline
  - `decisions_made` and `decision_log` arrays
  - Signals: `budget_changed`, `week_changed`, `decision_made`, `game_over`

- **DecisionManager autoload** - New decision logic system
  - Loads `data/decisions.json` with 20 project decisions
  - `make_decision(id)` applies costs and effects
  - `can_make_decision(id)` returns availability with reasons
  - `get_trajectory_text()` and `get_trajectory_snark()` for status summaries
  - `calculate_ending()` determines final tier based on scores

- **Decision data** (`data/decisions.json`)
  - 20 decisions across 5 categories: scoping, data, technical, talent, political
  - Each decision has: cost (budget, time), impact (7 scores), prerequisites, excludes
  - Costs visible to player; score impacts hidden until ending

#### UI
- **HUD** (`scenes/ui/hud.tscn`, `scripts/hud.gd`)
  - Always-visible budget bar with color coding (green/yellow/red)
  - Week counter with time pressure colors
  - CHIP companion integration

- **Status Screen** (`scenes/ui/status_screen.tscn`, `scripts/status_screen.gd`)
  - Press Tab to toggle
  - Shows all 7 Critical scores with progress bars
  - Budget and week display
  - Trajectory summary text
  - Decision count

- **Ending Screen** (`scenes/ui/ending_screen.tscn`, `scripts/ending_screen.gd`)
  - Triggered by game_over signal (budget=0 or week>16)
  - 5 tiers: catastrophic, partial_failure, mixed, success, exceptional
  - Shows final scores with bars and summaries
  - Narrative text, CHIP final line, closing text
  - Play Again button

- **CHIP Companion** (`scenes/chip.tscn`, `scripts/chip.gd`)
  - Snarky AI assistant in top-right corner
  - Contextual commentary based on game state
  - Triggers: idle, budget_low, score_critical, time_pressure, milestones
  - Click to dismiss messages

- **CHIP dialogue** (`data/chip_lines.json`)
  - ~50 lines across categories: idle, budget, scores, time, decisions, NPCs

- **Endings data** (`data/endings.json`)
  - 5 tier definitions with title, subtitle, narrative, closing, CHIP line
  - Score summaries for each of the 7 metrics
  - Special variations for achievements (e.g., harry_champion)

#### Dialogue Extensions
- **Locked choice display** - Choices with `requires` field shown grayed out
  - Displays requirement text: "✓ Trust ≥ 5" or "✗ Trust ≥ 5 (You have: 2)"
  - Shows cost on decision choices: "Cost: $45K | 2 weeks"

- **`adds_decision` field** - Dialogue choices can trigger decisions
- **`requires` vs `conditions`** distinction:
  - `conditions`: Hidden choices (removed if unmet)
  - `requires`: Visible locked choices (grayed out with requirements)

#### NPCs
- **Harry Vance** - CEO & Founder NPC (`data/dialogue/harry.json`)
  - First meeting: Skeptical introduction, asks "What makes you different?"
  - Return visits: Check progress based on scores
  - High trust (≥20): Becomes project champion
  - Low trust (≤-5): Final warning conversation
  - Trust-based branching and flag system

### Changed
- **DialogueManager** - Extended for decision integration
  - New `decision_triggered` signal
  - `get_all_choices_with_status()` returns availability info for locked display
  - Handles `adds_decision` and `requires` fields

- **DialogueBox** - Enhanced choice display
  - Shows locked choices with requirement text
  - Color-coded: available (white), locked (gray)
  - Displays decision costs when `show_cost` is true

- **GameState** - Extended with budget and timeline
  - `spend_budget()`, `advance_week()`, `record_decision()` methods
  - `check_conditions_detailed()` returns pass/fail reasons for UI
  - `get_critical_failures()` for ending calculation

### Technical
- Added `DecisionManager` to project.godot autoloads
- HUD, StatusScreen, EndingScreen added to main.tscn
- Harry NPC added to main.tscn with position and dialogue_id

---

## [0.1.1] - State & Dialogue System

### Added
- **GameState autoload** - Central state management singleton
  - Tracks 7 scores: strategy, data, technical, innovation, change, talent, trust
  - Manages flags array for story progression
  - Tracks which NPCs the player has talked to
  - `check_conditions()` evaluates complex condition dictionaries
  - `apply_effects()` modifies state from dialogue choices

- **DialogueManager autoload** - Conversation flow controller
  - Loads per-NPC dialogue from `data/dialogue/{npc_id}.json`
  - Supports node-based branching conversations
  - Evaluates conditions on nodes and choices
  - Emits signals: `dialogue_started`, `node_displayed`, `choices_presented`, `dialogue_ended`
  - Automatic conversation selection (first_meeting vs return_visit)

- **Branching dialogue system**
  - Choice buttons in dialogue box (up to 3 choices)
  - Keyboard selection (1/2/3 keys) or click
  - Conditional choices that appear/hide based on game state
  - Cross-NPC references (e.g., Sage knows if you've talked to Delta)

- **NPC dialogue JSON files**
  - `data/dialogue/sage.json` - Strategy consultant with ROI discussion
  - `data/dialogue/delta.json` - Data engineer with quality concerns
  - `data/dialogue/nova.json` - ML engineer with prototype demos

- **BounceAnimator component** (`scripts/bounce_animator.gd`)
  - Reusable animation system for any character
  - Idle bob animation (gentle vertical movement)
  - Walking bounce with side-to-side hop and rotation
  - Procedural shadow generation and animation
  - Configurable via exports (bob height, period, shadow scale, etc.)

- **NPC wandering behavior**
  - NPCs move one tile (48px) in cardinal directions
  - Random wait times between moves (10-30 seconds)
  - Pauses during dialogue
  - Physics-based movement with collision handling

- **Pushable NPCs**
  - NPCs changed from StaticBody2D to RigidBody2D
  - Configurable mass and friction
  - Player can nudge NPCs around the map

### Changed
- **DialogueBox** now connects to DialogueManager signals instead of loading JSON directly
- **NPCs** call `DialogueManager.start_conversation()` instead of `dialogue_box.start_dialogue()`
- **Player** connects to DialogueManager signals for movement control
- **main.gd** no longer manually wires NPCs to dialogue box

### Technical
- Added `GameState` and `DialogueManager` to project.godot autoloads
- Dialogue JSON moved from single `data/dialogue.json` to per-NPC files in `data/dialogue/`
- Added ChoicesContainer with 3 Button nodes to dialogue_box.tscn

---

## [0.1.0] - 2024-12-30

### Added
- Initial project setup with Godot 4.5
- Player character with 8-direction movement
- Basic NPC interaction with Area2D zones
- Simple linear dialogue system
- TileMap-based office environment
- GameManager autoload for dialogue state
