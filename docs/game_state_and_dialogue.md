# Critical 7 — State System & Dialogue Implementation

## Overview

**Goal:** Implement a state management system and state-based dialogue system that allows NPCs to have dynamic, branching conversations that react to player choices and game state.

**Scope:** This stage focuses on the core systems. No minigames, no battle, no CHIP companion yet.

---

## End State Demo

When this stage is complete, the following should work:

1. Player walks up to NPC, presses Space
2. Dialogue box appears with NPC's opening line
3. Player sees 1-3 response options (or just "Continue" for linear dialogue)
4. Player selects an option
5. Option triggers:
   - Next dialogue node displays, AND/OR
   - State changes (scores, flags, talked_to tracking)
6. Conversation continues until reaching a terminal node
7. Dialogue box closes
8. Player can talk to same NPC again — dialogue is different based on state
9. Player talks to different NPC — their dialogue reflects state changes

---

## System 1: GameState (Autoload Singleton)

### Purpose
Central store for all game state. Persists across scenes. Single source of truth.

### State Properties

```
GameState
├── scores: Dictionary
│   ├── strategy: int (default 0)
│   ├── data: int (default 0)
│   ├── technical: int (default 0)
│   ├── innovation: int (default 0)
│   ├── change: int (default 0)
│   ├── talent: int (default 0)
│   └── trust: int (default 0)
├── expectations_gap: int (default 0)
├── talked_to: Array[String] (NPCs the player has talked to)
├── flags: Array[String] (story flags that have been set)
├── current_day: int (default 1)
└── dialogue_history: Dictionary (tracks last node visited per NPC)
```

### Required Methods

| Method | Signature | Purpose |
|--------|-----------|---------|
| `apply_effects` | `(effects: Dictionary) -> void` | Apply score/flag changes from dialogue |
| `set_flag` | `(flag: String) -> void` | Add flag to flags array |
| `unset_flag` | `(flag: String) -> void` | Remove flag from flags array |
| `has_flag` | `(flag: String) -> bool` | Check if flag is set |
| `mark_talked_to` | `(npc_id: String) -> void` | Add NPC to talked_to array |
| `has_talked_to` | `(npc_id: String) -> bool` | Check if player talked to NPC |
| `get_talked_to_count` | `() -> int` | Return number of NPCs talked to |
| `check_conditions` | `(conditions: Dictionary) -> bool` | Evaluate if conditions are met |
| `reset` | `() -> void` | Reset all state to defaults (for new game) |

### Effects Dictionary Format

When dialogue applies effects, the dictionary looks like:

```gdscript
{
    "strategy": 10,        # Add to score
    "data": -5,            # Subtract from score
    "expectations_gap": 5, # Modify expectations
    "set_flags": ["learned_roi", "sage_impressed"],  # Flags to set
    "unset_flags": ["first_meeting"]                  # Flags to remove
}
```

### Conditions Dictionary Format

Dialogue nodes/choices can have conditions:

```gdscript
{
    "talked_to": ["sage", "delta"],           # Must have talked to these
    "not_talked_to": ["ceo"],                 # Must NOT have talked to these
    "flags": ["learned_roi"],                 # Must have these flags
    "not_flags": ["already_failed"],          # Must NOT have these flags
    "score_min": {"strategy": 20},            # Minimum score requirements
    "score_max": {"expectations_gap": 50}     # Maximum score requirements
}
```

All conditions must be true for the check to pass (AND logic).

---

## System 2: DialogueManager (Autoload Singleton)

### Purpose
Loads dialogue data, manages conversation flow, evaluates conditions, emits signals for UI.

### Properties

```
DialogueManager
├── dialogue_data: Dictionary (all loaded dialogue)
├── current_npc_id: String
├── current_conversation_id: String
├── current_node_id: String
└── is_active: bool
```

### Required Methods

| Method | Signature | Purpose |
|--------|-----------|---------|
| `load_dialogue` | `(npc_id: String) -> Dictionary` | Load NPC's dialogue from JSON |
| `start_conversation` | `(npc_id: String) -> void` | Begin conversation with NPC |
| `get_current_node` | `() -> Dictionary` | Return current node data |
| `get_available_choices` | `() -> Array` | Return choices that pass conditions |
| `select_choice` | `(index: int) -> void` | Process player's choice |
| `advance` | `() -> void` | Move to next node (for linear dialogue) |
| `end_conversation` | `() -> void` | Clean up and close dialogue |
| `select_conversation` | `(npc_id: String) -> String` | Pick which conversation to use based on state |

### Signals

| Signal | Parameters | When Emitted |
|--------|------------|--------------|
| `dialogue_started` | `npc_id: String` | Conversation begins |
| `node_displayed` | `node: Dictionary` | New node should be shown |
| `choices_presented` | `choices: Array` | Player needs to pick option |
| `dialogue_ended` | | Conversation finished |

### Conversation Selection Logic

When `start_conversation` is called, the manager must pick WHICH conversation to use:

```
1. Get all conversations for this NPC
2. For each conversation, check its trigger:
   - "first_meeting": Use if NPC not in talked_to
   - "return_visit": Use if NPC already in talked_to
   - "flag:some_flag": Use if flag is set
   - "default": Fallback
3. Return the first matching conversation
4. Mark NPC as talked_to
```

### Node Processing Logic

When displaying a node:

```
1. Get node from current conversation
2. If node has "conditions", check them via GameState.check_conditions()
3. If conditions fail, skip to node's "fallback" or end conversation
4. If node has "effects", apply them via GameState.apply_effects()
5. If node has "flags.set", set them
6. If node has "flags.unset", unset them
7. Emit node_displayed signal with node data
8. If node has "choices", filter by conditions, emit choices_presented
9. If no choices and node has "next", wait for advance() call
10. If no choices and no "next", conversation ends
```

---

## System 3: DialogueBox (UI)

### Purpose
Display dialogue text and choices. Respond to DialogueManager signals.

### Scene Structure

```
DialogueBox (CanvasLayer)
└── PanelContainer
    └── VBoxContainer
        ├── NameLabel (Label) — NPC name
        ├── TextLabel (RichTextLabel) — Dialogue text
        ├── ChoicesContainer (VBoxContainer) — Holds choice buttons
        │   ├── ChoiceButton1 (Button)
        │   ├── ChoiceButton2 (Button)
        │   └── ChoiceButton3 (Button)
        └── ContinuePrompt (Label) — "Press Space to continue"
```

### Behavior

| State | Display |
|-------|---------|
| Linear dialogue (no choices) | Text + ContinuePrompt visible, ChoicesContainer hidden |
| Choice dialogue | Text + ChoiceButtons visible, ContinuePrompt hidden |
| Hidden | Entire DialogueBox not visible |

### Input Handling

- **Space/Enter** (when no choices): Call `DialogueManager.advance()`
- **1/2/3 keys or click** (when choices): Call `DialogueManager.select_choice(index)`
- **Escape**: Optionally allow closing dialogue early (or disable)

### Required Methods

| Method | Signature | Purpose |
|--------|-----------|---------|
| `show_node` | `(node: Dictionary) -> void` | Display node text and name |
| `show_choices` | `(choices: Array) -> void` | Create/show choice buttons |
| `hide_choices` | `() -> void` | Clear choice buttons |
| `show` | `() -> void` | Make dialogue box visible |
| `hide` | `() -> void` | Hide dialogue box |

---

## System 4: NPC Interaction

### Purpose
Detect when player can interact with NPC. Trigger dialogue on input.

### NPC Scene Structure

```
NPC (CharacterBody2D or StaticBody2D)
├── Sprite2D — NPC visual
├── CollisionShape2D — Physical collision
├── InteractionArea (Area2D) — Detects player proximity
│   └── CollisionShape2D — Larger than physical collision
└── InteractionPrompt (Label) — "Press Space to talk" (initially hidden)
```

### NPC Script Properties

```gdscript
@export var npc_id: String  # Must match dialogue JSON filename
@export var display_name: String  # Shown in dialogue box
```

### Behavior

1. Player enters InteractionArea → Show InteractionPrompt
2. Player exits InteractionArea → Hide InteractionPrompt
3. Player presses Space while in area → Call `DialogueManager.start_conversation(npc_id)`
4. While dialogue is active → Player movement disabled

---

## Dialogue JSON Format

### File Location
```
res://data/dialogue/{npc_id}.json
```

### Complete Schema

```json
{
  "id": "npc_id",
  "character": {
    "name": "Display Name",
    "title": "Optional Subtitle",
    "portrait": "res://assets/portraits/npc.png"
  },
  "conversations": {
    "conversation_id": {
      "trigger": "first_meeting | return_visit | flag:flag_name | default",
      "trigger_conditions": { },
      "start_node": "node_id",
      "nodes": {
        "node_id": {
          "speaker": "npc | player | narrator",
          "text": "Dialogue text here.",
          "conditions": { },
          "effects": { },
          "flags": {
            "set": ["flag1", "flag2"],
            "unset": ["flag3"]
          },
          "next": "next_node_id | null",
          "choices": [
            {
              "text": "Player response text",
              "conditions": { },
              "effects": { },
              "flags": { "set": [], "unset": [] },
              "next": "resulting_node_id"
            }
          ]
        }
      }
    }
  }
}
```

### Node Types (by structure)

**Linear Node** — Has `next`, no `choices`:
```json
{
  "speaker": "npc",
  "text": "Hello there.",
  "next": "node_2"
}
```

**Choice Node** — Has `choices`, no `next`:
```json
{
  "speaker": "npc",
  "text": "What do you think?",
  "choices": [
    { "text": "Option A", "next": "response_a" },
    { "text": "Option B", "next": "response_b" }
  ]
}
```

**Terminal Node** — Has `"next": null`, no `choices`:
```json
{
  "speaker": "npc",
  "text": "Goodbye.",
  "next": null
}
```

**Conditional Choice** — Choice only appears if conditions pass:
```json
{
  "text": "I heard about the data problems from Delta...",
  "conditions": { "talked_to": ["delta"] },
  "effects": { "strategy": 10 },
  "next": "impressed_response"
}
```

---

## Test Scenarios

After implementation, these scenarios should work:

### Scenario 1: Basic Conversation
1. Talk to Sage
2. See her opening line
3. Press Space to continue
4. See next line
5. Conversation ends
6. Dialogue box closes

### Scenario 2: Choices
1. Talk to Sage
2. Reach a choice node
3. See 3 options displayed
4. Click option 2
5. See response based on choice
6. Conversation continues

### Scenario 3: State Changes
1. Talk to Sage, pick option that sets flag "learned_roi"
2. End conversation
3. Check GameState — flag should be set
4. Check GameState — "sage" should be in talked_to

### Scenario 4: Return Visit
1. Talk to Sage (first_meeting conversation)
2. End conversation
3. Talk to Sage again
4. Should see return_visit conversation (different opening)

### Scenario 5: Conditional Dialogue
1. Talk to Delta first
2. Talk to Sage
3. Sage should have special line acknowledging you talked to Delta

### Scenario 6: Conditional Choice
1. Talk to Sage (without talking to Delta first)
2. Reach choice node
3. Should NOT see option that requires talking to Delta
4. Talk to Delta
5. Talk to Sage again, reach same choice
6. NOW see the Delta-dependent option

### Scenario 7: Score Effects
1. Note starting strategy score (0)
2. Talk to Sage, make choice with `"effects": { "strategy": 10 }`
3. End conversation
4. Check GameState — strategy should be 10

---

## File Checklist

After implementation, these files should exist:

```
project/
├── autoload/
│   ├── game_state.gd         # GameState singleton
│   └── dialogue_manager.gd   # DialogueManager singleton
├── scenes/
│   ├── ui/
│   │   └── dialogue_box.tscn # Dialogue UI scene
│   │   └── dialogue_box.gd   # Dialogue UI script
│   └── npcs/
│       └── npc.tscn          # Base NPC scene
│       └── npc.gd            # Base NPC script
├── data/
│   └── dialogue/
│       ├── sage.json         # Test NPC dialogue
│       └── delta.json        # Second test NPC
└── project.godot             # Updated with autoloads
```

---

## Implementation Order

1. **GameState** — Create autoload with all properties and methods
2. **Test GameState** — Verify methods work via print statements
3. **DialogueManager** — Create autoload with signals and methods
4. **DialogueBox UI** — Create scene and connect to DialogueManager signals
5. **Test with hardcoded data** — Verify UI works before JSON loading
6. **JSON loading** — Implement `load_dialogue` method
7. **NPC interaction** — Create base NPC scene with interaction area
8. **Wire it together** — NPC triggers DialogueManager, UI responds
9. **Test basic flow** — Scenario 1 and 2
10. **Add state tracking** — Implement effects, flags, talked_to
11. **Test state flow** — Scenarios 3-7
12. **Add conditional logic** — Implement condition checking
13. **Test conditionals** — Scenarios 5 and 6
14. **Create test dialogue** — Write sage.json and delta.json with cross-references

---

## Out of Scope (This Stage)

- CHIP companion
- Minigames
- CEO check-ins (auto-triggered)
- Multiple rooms/scenes
- Day system
- Save/load
- Final battle
- Typewriter text effect
- Portraits
- Sound effects

---

## Acceptance Criteria

This stage is complete when:

- [ ] GameState autoload exists with all properties and methods
- [ ] DialogueManager autoload exists with all methods and signals
- [ ] DialogueBox UI displays text and choices correctly
- [ ] Player can interact with NPC to start dialogue
- [ ] Dialogue advances on Space press
- [ ] Choices are displayed and selectable
- [ ] Selecting choice leads to correct next node
- [ ] Effects modify GameState scores
- [ ] Flags are set/unset correctly
- [ ] talked_to tracks NPCs correctly
- [ ] Return visits show different conversation
- [ ] Conditional choices appear/hide based on state
- [ ] Cross-NPC state references work (talked to X affects Y's dialogue)
- [ ] Player movement disabled during dialogue
- [ ] All 7 test scenarios pass