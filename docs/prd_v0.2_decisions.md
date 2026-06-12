# Critical 7 — PRD v0.2: Decisions & Game Loop

**Status: COMPLETED**

---

## Overview

**Project:** Critical 7 - AI Strategy Adventure Game
**Version:** 0.2 (Decisions & Game Loop)
**Engine:** Godot 4.6 (Compatibility Renderer for web export)
**Target Platform:** Web
**Tone:** Office Punk meets Portal 2 meets Chrono Trigger

---

## Phase Goals

This phase establishes the **core game loop**: make decisions that affect resources and the Critical 7 scores, see the consequences play out, and reach an ending based on cumulative choices.

### What's IN Scope
- Decision system with budget/time costs
- Critical 7 scores visible as "ability scores"
- D&D-style skill checks on dialogue options
- Project status HUD (budget, timeline, scores)
- CHIP companion (helper/narrator)
- Decision log and trajectory summary
- Basic ending system based on final scores
- Harry (CEO) as interactive NPC

### What's OUT of Scope
- Multiple floors/rooms (single map for now)
- Full 7 guide NPCs (keep Sage, Delta, Nova; add 1-2 more)
- Surreal office transformations (visual only, no gameplay impact yet)
- Sound/music
- Save system
- Final boss battle mechanics

---

## Story Context

**Company:** Nexus Dynamics - mid-sized logistics company, bleeding market share to Congo
**Project:** Project Atlas - $750K budget, 16 weeks to "transform with AI"
**Player:** External consultant, 4th person to try this, probably the scapegoat
**Stakes:** If this fails, Harry's done with AI. Maybe done with Nexus.

See [docs/story.md](story.md) for full narrative context.

---

## Functional Requirements

### 1. Decision System

**FR-1.1** Decisions are the core gameplay unit
- Each decision has: id, title, icon, description, budget cost, time cost, Critical 7 impacts

**FR-1.2** Decisions are triggered through dialogue
- Dialogue choices can include `adds_decision` field
- Some decisions can be reversed via `reverses` field

**FR-1.3** Costs are visible, impacts are hidden
- Player sees: "This costs $45K and takes 2 weeks"
- Player doesn't see: "+15 Data, -5 Change" (revealed at endgame)

**FR-1.4** Decisions can have prerequisites
- `min_scores`: Require minimum Critical 7 values
- `flags`: Require story flags
- `decisions`: Require prior decisions
- `not_decisions`: Locked out by prior decisions

**FR-1.5** Mutually exclusive decisions
- Some decisions `exclude` others permanently

See [docs/decisions.md](decisions.md) for full specification.

### 2. Critical 7 Scores (D&D Style)

**FR-2.1** Scores are always visible in a stats panel
```
┌─────────────────────────────────────┐
│ THE CRITICAL 7                      │
├─────────────────────────────────────┤
│ Strategy    ██████████░░░░  12      │
│ Data        ████████████░░  15      │
│ Technical   ██████████░░░░  10      │
│ Innovation  ████████░░░░░░   8      │
│ Change      ██████░░░░░░░░   6      │
│ Talent      ██████████░░░░  10      │
│ Trust       ████████████░░  14      │
└─────────────────────────────────────┘
```

**FR-2.2** Score thresholds unlock dialogue options
| Range | Meaning |
|-------|---------|
| 0-4 | Weak - basic options only |
| 5-9 | Developing - some advanced options |
| 10-14 | Solid - most options available |
| 15-19 | Strong - premium options unlock |
| 20+ | Exceptional - secret paths |
| Negative | Critical - bad events trigger |

**FR-2.3** Skill checks shown on dialogue choices
- ✓ Green checkmark = requirement met
- ✗ Red X = requirement not met (shows current value)
- Locked options visible but grayed out

### 3. Resources: Budget & Timeline

**FR-3.1** Budget
- Starting: $750,000
- Displayed as bar + number
- Decisions cost or save money
- Budget ≤ 0 = catastrophic failure ending

**FR-3.2** Timeline
- 16 weeks total
- Displayed as "Week X of 16" + progress bar
- Decisions consume weeks (not real-time)
- Week 16 reached = project ends, evaluate scores

**FR-3.3** No real-time pressure
- Time only passes when decisions are made
- Player can explore freely without time penalty

### 4. Project Status HUD

**FR-4.1** Minimal HUD always visible
- Budget bar (compact)
- Week indicator
- CHIP icon (clickable for help)

**FR-4.2** Full status screen (Tab or menu)
- Critical 7 scores with bars
- Budget remaining
- Current week
- Trajectory summary (qualitative)
- Decision count
- Link to decision log

**FR-4.3** Trajectory summary
- Generated from scores without revealing exact numbers
- Examples:
  - "Data foundations are solid"
  - "The team is burning out"
  - "Executives are losing confidence"

### 5. CHIP Companion

**FR-5.1** CHIP appears as small floating helper
- Corner of screen, bounces when has something to say
- Click to get contextual advice

**FR-5.2** CHIP triggers
- Idle too long: Suggests who to talk to
- Budget low: Warns about spending
- Score critical: Hints at problems
- Locked option selected: Snarky explanation
- Good decision: Positive reinforcement

**FR-5.3** CHIP personality
- Helpful but slightly glitchy
- Corporate speak with dark undertones
- References "previous project leads"
- Occasionally knows things it shouldn't

**FR-5.4** Sample CHIP lines
- "Hey! Listen! ...Sorry, that's from my training data."
- "Bold of you to assume they'd agree to that. Have you tried... being likeable?"
- "Fun fact: You're the 4th project lead I've assisted. The others are... no longer with the company."
- "That ship has sailed. It's in the space between spaces now. With the packages."

### 6. Decision Log

**FR-6.1** Chronological list of all decisions made
- Shows title, cost, time, week made
- Impacts hidden until endgame

**FR-6.2** Accessible from status screen

**FR-6.3** Endgame reveals full impact of each decision

### 7. Dialogue System Updates

**FR-7.1** Extend choice format
```json
{
  "text": "Let's do the risky integration.",
  "requires": {
    "min_scores": { "technical": 10 }
  },
  "adds_decision": "risky_integration",
  "effects": { "technical": 5 }
}
```

**FR-7.2** Show requirements on choices
- Requirements displayed below choice text
- Met requirements in green, unmet in red

**FR-7.3** Locked choices visible but not selectable

### 8. Ending System

**FR-8.1** Ending triggers at Week 16 or Budget = 0

**FR-8.2** Ending tiers based on evaluation:
| Tier | Condition |
|------|-----------|
| Catastrophic | Budget depleted OR multiple critical scores |
| Partial Failure | Finished but low total OR critical failures |
| Mixed Results | Moderate scores, some wins/losses |
| Success | Strong scores across the board |
| Exceptional | High scores + special achievements |

**FR-8.3** Ending screen shows:
- Final Critical 7 scores
- Full decision log with revealed impacts
- Narrative summary of what happened
- Option to replay

### 9. New NPCs

**FR-9.1** Harry Vance (CEO)
- Location: Corner office (separate area or same map)
- Key dialogue around expectations, timelines, trust
- Can become obstacle, ally, or champion based on Trust score

**FR-9.2** At least one more guide (pick from):
- **Technical guide** - Platform architect / DevOps
- **Change guide** - HR / Internal comms
- **Talent guide** - Training lead
- **Trust guide** - Legal / Ethics

---

## Technical Requirements

### GameState Updates

```gdscript
# Add to game_state.gd
var budget: int = 750000
var budget_total: int = 750000
var current_week: int = 1
var total_weeks: int = 16
var decisions_made: Array[String] = []
var decision_log: Array[Dictionary] = []
```

### New Autoload: DecisionManager

```gdscript
# scripts/decision_manager.gd
signal decision_made(decision_id: String)
signal week_advanced(new_week: int)
signal budget_changed(new_budget: int)
signal game_ended(ending_tier: String)

func make_decision(decision_id: String) -> bool
func can_make_decision(decision_id: String) -> Dictionary  # Returns {allowed, reasons}
func get_trajectory_text() -> String
func advance_week(weeks: int = 1) -> void
func check_game_end() -> void
```

### New Scenes

- `scenes/ui/hud.tscn` - Minimal always-visible HUD
- `scenes/ui/status_screen.tscn` - Full project status
- `scenes/ui/decision_log.tscn` - Decision history view
- `scenes/ui/ending_screen.tscn` - End of game summary
- `scenes/chip.tscn` - CHIP companion sprite + logic

### New Data Files

- `data/decisions.json` - All decision definitions
- `data/chip_lines.json` - CHIP dialogue by trigger type
- `data/endings.json` - Ending text by tier
- `data/dialogue/harry.json` - CEO dialogue

---

## UI Mockups

### Minimal HUD
```
┌────────────────────────────────────────────────────┐
│ $485K ████████░░  │  Week 7/16  │  [CHIP icon]    │
└────────────────────────────────────────────────────┘
```

### Dialogue with Skill Check
```
┌─────────────────────────────────────────────────────┐
│ Delta                                               │
├─────────────────────────────────────────────────────┤
│ "We could try the direct integration, but it's     │
│  risky. What do you want to do?"                   │
├─────────────────────────────────────────────────────┤
│ [1] "Let's do it. I trust the team."               │
│     ✓ Technical ≥ 10  ✓ Talent ≥ 5                 │
│     Cost: $20K | Time: 2 weeks                     │
│                                                     │
│ [2] "Build an abstraction layer instead."          │
│     ✗ Technical ≥ 15 (You have: 10)                │
│     [LOCKED]                                        │
│                                                     │
│ [3] "Let's avoid the legacy system entirely."      │
│     Cost: $0 | Time: 0                             │
└─────────────────────────────────────────────────────┘
```

---

## Acceptance Criteria

### Decision System
- [x] Decisions can be triggered from dialogue
- [x] Budget and time costs are deducted immediately
- [x] Critical 7 impacts are applied but hidden
- [x] Prerequisites are checked before allowing decisions
- [x] Mutually exclusive decisions lock each other out

### UI
- [x] Minimal HUD shows budget, week, CHIP
- [x] Status screen shows all Critical 7 scores
- [x] Dialogue shows requirements on choices
- [x] Locked choices are visible but grayed out
- [ ] Decision log accessible and accurate — standalone decision_log.tscn not yet built

### CHIP
- [x] CHIP appears — implemented as in-world companion that follows player (evolved beyond original corner-icon concept)
- [x] CHIP comments on idle, low budget, locked options
- [x] CHIP has distinct snarky personality

### Game Loop
- [x] Game ends at Week 16 (triggers boss fight) or Budget = 0
- [x] Ending tier calculated from scores
- [x] Ending screen shows full decision breakdown
- [x] Player can understand what went right/wrong

### Content
- [x] 30 decisions available (exceeded 15-20 target)
- [x] Harry (CEO) is interactable
- [x] Multiple dialogue paths based on scores
- [x] 5 distinct ending tiers playable

---

## Implementation Order

1. **GameState & DecisionManager** - Add budget, timeline, decision tracking
2. **Decisions data** - Create decisions.json with 10-15 sample decisions
3. **Dialogue updates** - Add requires, adds_decision to choice schema
4. **HUD** - Minimal always-visible budget/week/CHIP
5. **Status screen** - Full Critical 7 display
6. **Skill checks in UI** - Show requirements on dialogue choices
7. **CHIP basic** - Sprite, click interaction, basic triggers
8. **Decision log** - View past decisions
9. **Ending system** - Week 16 trigger, tier calculation, summary screen
10. **Harry NPC** - Add CEO with dialogue
11. **CHIP polish** - More lines, better triggers
12. **Playtest & balance** - Adjust costs, impacts, pacing

---

## Open Questions (Resolved)

1. **Decision count:** 30 decisions implemented
2. **Week pacing:** Decisions consume variable weeks (1-3)
3. **Score starting values:** All start at 0
4. **CHIP visibility:** In-world companion that follows the player (evolved from corner icon)
5. **Multiple playthroughs:** Clean restart (Play Again button on ending screen)

---

## Beyond Original Scope

The following were originally out of scope but were implemented during v0.2:

- **Boss Fight** ("The Board Presentation") — action budget end-game sequence at week 16+, with objectives tied to NPCs and scores
- **Full 7 NPCs** — Rex (Technical), Morgan (Change), Casey (Talent) added alongside Sage, Delta, Nova, Harry
- **Terminal System** — computer for sending company-wide messages with prepared/unprepared variants
- **Interactables** — breakable boxes, readables, containers, switches
- **Sprite Sheet Animation** — CharacterAnimator builds SpriteFrames at runtime from character sheets
- **Character Portraits** — 96x96 pixel art portraits for all characters
- **Pixel Art HUD** — NinePatch-based UI from sprite sheet

---

## Not Yet Implemented

- **Web export** — not tested
- **Sound/music**
- **Save system**
- **Decision log standalone view** — planned `decision_log.tscn` not built
- **Playtest & balance pass**

---

## Related Documents

- [Story & World Design](story.md)
- [Decisions System Spec](decisions.md)
- [Characters](characters.md)
- [Previous PRD (v0.1)](prd_v0.1_prototype.md)
