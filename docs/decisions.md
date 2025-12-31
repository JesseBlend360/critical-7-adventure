# Decisions System

## Overview

Decisions are the core gameplay unit. Every meaningful choice the player makes is recorded as a Decision that affects:
- **Budget** (immediate, visible)
- **Time** (immediate, visible)
- **Critical 7 scores** (hidden until endgame summary)

The player sees the cost upfront but discovers the full impact at the end - just like real projects.

---

## Decision Data Structure

```json
{
  "id": "hire_data_consultant",
  "title": "Hire External Data Consultant",
  "icon": "person_add",
  "category": "talent",
  "description": "Bring in a specialist to audit and clean the customer database.",
  "cost": {
    "budget": 45000,
    "time": 2
  },
  "impact": {
    "strategy": 0,
    "data": 15,
    "technical": 5,
    "innovation": 0,
    "change": -5,
    "talent": 10,
    "trust": 5
  },
  "visible_impact": false,
  "reversible": false,
  "prerequisites": ["met_delta"],
  "unlocks": ["data_audit_complete"],
  "flavor_text": "Delta finally smiles. You didn't know she could do that."
}
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier for the decision |
| `title` | string | Short display name |
| `icon` | string | Icon identifier (defined separately) |
| `category` | string | Primary Critical 7 category this relates to |
| `description` | string | What this decision represents |
| `cost.budget` | int | Dollar cost (can be negative for savings) |
| `cost.time` | int | Weeks consumed (can be 0 for instant decisions) |
| `impact` | object | Effect on each Critical 7 score (hidden by default) |
| `visible_impact` | bool | If true, show impact immediately (rare) |
| `reversible` | bool | Can this decision be undone? |
| `prerequisites` | array | Flags/decisions required before this is available |
| `unlocks` | array | Flags set when this decision is made |
| `flavor_text` | string | Optional narrative text shown when decision is made |

---

## Categories (The Critical 7)

| ID | Name | What It Measures |
|----|------|------------------|
| `strategy` | Business Strategy | Alignment with business goals, ROI, executive buy-in |
| `data` | Data Foundations | Data quality, governance, infrastructure |
| `technical` | Technical Approach | Architecture, scalability, engineering practices |
| `innovation` | Innovation | Experimentation, prototyping, creative solutions |
| `change` | Change Management | Adoption, communication, process transformation |
| `talent` | Workforce/Talent | Skills, training, team health, hiring |
| `trust` | Trust | Stakeholder confidence, ethics, managing expectations |

---

## How Decisions Flow

### 1. Dialogue Triggers Decision
```json
// In dialogue JSON
{
  "text": "Should we bring in outside help for the data cleanup?",
  "choices": [
    {
      "text": "Yes, hire a consultant.",
      "adds_decision": "hire_data_consultant"
    },
    {
      "text": "No, we'll handle it internally.",
      "adds_decision": "internal_data_cleanup"
    },
    {
      "text": "Let's skip the cleanup for now.",
      "adds_decision": "skip_data_cleanup"
    }
  ]
}
```

### 2. Decision is Recorded
- Added to player's decision log
- Budget deducted immediately
- Time consumed immediately
- Critical 7 impacts applied (but hidden)
- Any `unlocks` flags are set

### 3. Player Sees Limited Info
```
┌─────────────────────────────────────────┐
│ DECISION MADE                           │
│                                         │
│ 📋 Hire External Data Consultant        │
│                                         │
│ Cost: $45,000                           │
│ Time: 2 weeks                           │
│                                         │
│ "Delta finally smiles. You didn't       │
│  know she could do that."               │
└─────────────────────────────────────────┘
```

### 4. Endgame Reveals Full Impact
At project end, each decision is shown with its actual impact:
```
┌─────────────────────────────────────────┐
│ DECISION: Hire External Data Consultant │
├─────────────────────────────────────────┤
│ Cost: $45,000 | Time: 2 weeks           │
├─────────────────────────────────────────┤
│ Impact:                                 │
│   Data         ████████████████  +15    │
│   Talent       ██████████        +10    │
│   Technical    █████              +5    │
│   Trust        █████              +5    │
│   Change       ▓▓▓▓▓             -5     │
└─────────────────────────────────────────┘
```

---

## Decision Requirements & Exclusions

### Skill Checks (D&D Style)
Some dialogue options require minimum Critical 7 scores. These are shown directly in the UI:

```
┌─────────────────────────────────────────────────────┐
│ Delta: "We could try to integrate with the legacy   │
│ system directly, but it's risky."                   │
├─────────────────────────────────────────────────────┤
│ [1] "Let's do it. I trust the team."                │
│     ✓ Technical ≥ 10  ✓ Talent ≥ 5                  │
│                                                     │
│ [2] "Can we build an abstraction layer instead?"    │
│     ✗ Technical ≥ 15  (You have: 10)                │
│     ✓ Innovation ≥ 5                                │
│                                                     │
│ [3] "Let's avoid the legacy system entirely."       │
│     No requirements                                 │
└─────────────────────────────────────────────────────┘
```

**Visual Treatment:**
- ✓ Green checkmark + green text = requirement met
- ✗ Red X + red text = requirement NOT met (shows current value)
- Locked options are visible but not selectable (grayed out)
- Player can see what they're missing and work toward it

### Requirement Types

```json
{
  "text": "Let's do the risky integration.",
  "requires": {
    "min_scores": {
      "technical": 10,
      "talent": 5
    },
    "max_scores": {
      "trust": 25
    },
    "flags": ["delta_trusts_you"],
    "not_flags": ["burned_delta"],
    "decisions": ["completed_data_audit"],
    "not_decisions": ["skipped_data_audit"]
  },
  "adds_decision": "risky_integration"
}
```

| Requirement | Description |
|-------------|-------------|
| `min_scores` | Critical 7 scores must be ≥ value |
| `max_scores` | Critical 7 scores must be ≤ value (rare, for "you're too corporate" options) |
| `flags` | Story flags that must be set |
| `not_flags` | Story flags that must NOT be set |
| `decisions` | Previous decisions required |
| `not_decisions` | Decisions that would lock this out |

### Mutually Exclusive Decisions

Some decisions permanently lock out others:

```json
{
  "id": "build_custom",
  "title": "Build Custom Solution",
  "excludes": ["buy_vendor", "hybrid_approach"],
  ...
}
```

Once you commit to building custom, you can't switch to buying a vendor solution (without reversing first, if possible).

### Score Thresholds

The Critical 7 scores are visible like D&D ability scores:

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
├─────────────────────────────────────┤
│ Budget: $485K / $750K               │
│ Week: 7 / 16                        │
└─────────────────────────────────────┘
```

**Score Interpretation:**
| Range | Meaning | Unlocks |
|-------|---------|---------|
| 0-4 | Weak | Basic options only |
| 5-9 | Developing | Some advanced options |
| 10-14 | Solid | Most options available |
| 15-19 | Strong | Premium options unlock |
| 20+ | Exceptional | Secret/optimal paths |
| Negative | Critical | Triggers bad events, locks good options |

### Locked Option Snark

When an option is locked, CHIP might comment:

- **Technical too low:** "That would require... actually knowing how to do it. Perhaps more planning first?"
- **Trust too low:** "Bold of you to assume they'd agree to that. Have you tried... being likeable?"
- **Talent too low:** "The team would need to be significantly more... talented. No offense to the team."
- **Decision locked out:** "That ship has sailed. It's in the space between spaces now. With the packages."
- **Flag missing:** "You'd need Delta's buy-in for that. She's... not currently buying in."

---

## Reversing Decisions

Some decisions can be reversed through later dialogue:

```json
{
  "id": "cancel_vendor_contract",
  "title": "Cancel VendorAI Contract",
  "reverses": "sign_vendor_contract",
  "cost": {
    "budget": 25000,  // Early termination fee
    "time": 1
  },
  "impact": {
    // Opposite of original, plus penalty
    "trust": -10,
    "technical": 5,
    "innovation": 10
  }
}
```

Not everything is reversible:
- Hiring someone → can fire them (but costly)
- Promising a deadline → can't un-promise (trust damage is done)
- Launching a pilot → can't un-launch (but can kill it)

---

## Sample Decisions

### Early Game - Scoping
| ID | Title | Budget | Time | Primary Impact |
|----|-------|--------|------|----------------|
| `broad_scope` | "Boil the Ocean" Scope | $0 | 0 | Strategy -10, Trust -5 |
| `focused_scope` | Focused MVP Scope | $0 | 0 | Strategy +10, Innovation -5 |
| `pilot_first` | Start with Pilot | $0 | 0 | Trust +10, Strategy +5 |

### Data Decisions
| ID | Title | Budget | Time | Primary Impact |
|----|-------|--------|------|----------------|
| `skip_data_cleanup` | Skip Data Cleanup | $0 | 0 | Data -20, Time saved |
| `internal_data_cleanup` | Internal Data Cleanup | $15K | 3 | Data +10, Talent +5 |
| `hire_data_consultant` | Hire Data Consultant | $45K | 2 | Data +15, Change -5 |
| `full_data_audit` | Full Data Audit | $80K | 4 | Data +25, Technical +10 |

### Technical Decisions
| ID | Title | Budget | Time | Primary Impact |
|----|-------|--------|------|----------------|
| `build_custom` | Build Custom Solution | $150K | 6 | Technical +15, Innovation +10 |
| `buy_vendor` | Buy Vendor Solution | $200K | 2 | Technical -5, Trust +5 |
| `hybrid_approach` | Hybrid Build/Buy | $120K | 4 | Technical +5, Innovation +5 |

### People Decisions
| ID | Title | Budget | Time | Primary Impact |
|----|-------|--------|------|----------------|
| `mandatory_training` | Mandatory AI Training | $30K | 1 | Talent +15, Change -10 |
| `voluntary_training` | Opt-in AI Training | $15K | 0 | Talent +5, Change +5 |
| `hire_ml_engineer` | Hire ML Engineer | $80K | 3 | Technical +10, Talent +10 |
| `overwork_team` | Push Team to Meet Deadline | $0 | -2 | Talent -15, Trust -10 |

### Political Decisions
| ID | Title | Budget | Time | Primary Impact |
|----|-------|--------|------|----------------|
| `promise_impossible` | Promise Impossible Timeline | $0 | 0 | Trust -20 (delayed) |
| `honest_timeline` | Give Honest Timeline | $0 | 0 | Trust +10, Strategy -5 |
| `executive_demo` | Early Executive Demo | $10K | 1 | Strategy +10, Trust +5 |
| `skip_stakeholders` | Skip Stakeholder Alignment | $0 | -1 | Change -15, Trust -10 |

---

## Project Status Summary

At any time, the player can see a "trajectory" summary:

```
┌─────────────────────────────────────────────┐
│ PROJECT ATLAS - Status                      │
├─────────────────────────────────────────────┤
│ Budget:  $485,000 / $750,000  (64%)         │
│ Time:    Week 7 / 16          (44%)         │
├─────────────────────────────────────────────┤
│ Trajectory: CAUTIOUSLY OPTIMISTIC           │
│                                             │
│ "You're making good progress on data        │
│  foundations, but stakeholder alignment     │
│  is lagging. Consider scheduling time       │
│  with key decision makers."                 │
├─────────────────────────────────────────────┤
│ Decisions Made: 12                          │
│ [View Decision Log]                         │
└─────────────────────────────────────────────┘
```

The trajectory text is generated based on Critical 7 scores without revealing exact numbers:
- "Data foundations are solid" (Data > 15)
- "The team is burning out" (Talent < 0)
- "Executives are losing confidence" (Trust < 0, Strategy < 10)

---

## CHIP - The Helper Companion

### Concept
**CHIP** (Collaborative Heuristic Intelligence Partner) is a small AI assistant that appears in the corner of the screen. Think Navi from Ocarina of Time, but corporate.

CHIP was supposed to be Nexus Dynamics' internal AI assistant prototype. It... mostly works. It's helpful, earnest, and occasionally glitchy in unsettling ways.

### Personality
- Genuinely wants to help
- Speaks in slightly-too-corporate language
- Sometimes knows things it shouldn't
- Occasionally references "previous attempts" (the failed projects)
- Gets staticky when you're making bad decisions

### Triggers
CHIP speaks up when:
- Player is idle too long: "Hey! Have you considered checking in with Delta about the data pipeline?"
- Budget is low: "Alert: Budget utilization is at 78%. Consider reviewing upcoming expenditures."
- Time pressure: "Reminder: The stakeholder review is in 3 weeks. Current progress suggests..."
- Bad decision: *static* "Are you... sure about that? Historical data suggests..."
- Good decision: "Excellent choice! This aligns with successful project patterns."
- Stuck: "I notice you haven't spoken with Nova recently. She mentioned something about a prototype."

### Visual
- Small floating icon in corner (maybe a pixel art helper/fairy)
- Bounces or pulses when it has something to say
- Can be clicked to get contextual advice
- Sometimes appears in places it shouldn't (a hint at the office strangeness)

### Sample Lines
- "Hey! Listen! ...Sorry, that's from my training data. I mean: I have a suggestion."
- "Historical analysis of Project Falcon suggests this approach has a 23% success rate. Just FYI."
- "Delta seems frustrated. Her productivity metrics suggest she might need support."
- "I don't have data on what's in the basement. My records show it's been locked since... *static* ...2003."
- "Fun fact: You're the 4th project lead I've assisted. The others are... no longer with the company."

---

## Implementation Notes

### GameState Additions Needed
```gdscript
var budget: int = 750000
var budget_total: int = 750000
var current_week: int = 1
var total_weeks: int = 16
var decisions_made: Array[String] = []  # List of decision IDs
var decision_log: Array[Dictionary] = []  # Full decision records with timestamps
```

### New Decision Manager (Autoload?)
- `make_decision(decision_id: String)` - Apply a decision
- `can_make_decision(decision_id: String) -> bool` - Check prerequisites
- `reverse_decision(decision_id: String)` - If reversible
- `get_trajectory_text() -> String` - Generate status summary
- `get_decision_history() -> Array` - Return all decisions for display

### Dialogue System Updates
- Add `adds_decision` field to dialogue choices
- Add `removes_decision` field for reversals
- Add `requires_decision` for prerequisites
