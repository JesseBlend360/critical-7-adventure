# Characters — Critical 7

> Tongue-in-cheek fantasy races in an office setting. Every NPC is a fantasy archetype stuck in corporate life.

## The Player: Blenda

- **Role:** External AI Consultant, brought in to lead "Project Atlas"
- **Portrait:** Blue-haired woman with glasses (custom pixel art, `blenda_portrait_96.png`)
- **Sprite Sheet:** `blenda_01.png`
- **Personality:** The outsider. Sharp, adaptable, slightly overwhelmed. Has AI experience but no history at Nexus Dynamics.
- **Function:** Walks the office, talks to NPCs, makes decisions. The player's avatar.

---

## The Critical 7 NPCs

Each NPC is the champion of one of the 7 AI strategy dimensions. Their score rises or falls based on how the player engages with their domain.

### Sage — Strategy

| | |
|---|---|
| **Score** | Strategy |
| **Role** | External Strategy Consultant |
| **Portrait** | Elf woman with glasses — analytical, wise (#4) |
| **Personality** | Measured, analytical. Speaks in frameworks. Has seen AI projects fail before and is cautiously optimistic. |
| **Key Tension** | Wants rigorous planning vs. the pressure to "just ship something" |
| **Memorable Line** | *"A strategy without alignment is just a PowerPoint."* |

### Delta — Data

| | |
|---|---|
| **Score** | Data |
| **Role** | Senior Data Engineer, 12 years at Nexus |
| **Portrait** | Blue ogre in suit with hammer — blunt, imposing (#3) |
| **Personality** | Blunt, frustrated. Has been warning about data quality since 2019. Nobody listened. Cynical but competent. |
| **Key Tension** | Knows where all the data bodies are buried. Will help if you respect the work. |
| **Memorable Line** | *"I told them about the data problems in 2019. No one listened."* |

### Nova — Innovation

| | |
|---|---|
| **Score** | Innovation |
| **Role** | Junior ML Engineer, 6 months at Nexus |
| **Portrait** | Green cat in tech gear — chaotic, energetic (#8) |
| **Personality** | Energetic, chaotic. Ships demos at 2 AM. Has never seen production. Thinks everything is possible. |
| **Key Tension** | Enthusiasm vs. engineering discipline. Brilliant prototypes that may never scale. |
| **Memorable Line** | *"I already built a proof of concept! It only crashes sometimes."* |

### Harry — Trust

| | |
|---|---|
| **Score** | Trust |
| **Role** | CEO & Founder, 37 years at Nexus |
| **Portrait** | Bearded dwarf elder — skeptical, weathered (#17) |
| **Personality** | Skeptical, direct. Built the company from nothing. Doesn't understand AI but isn't stupid. Three failed AI projects have made him wary. Scared but won't admit it. |
| **Key Tension** | Wants to believe, but trust must be earned through honesty, not jargon. |
| **Memorable Line** | *"I've been in this business 37 years. I've never needed a machine to tell me when something smells wrong."* |

### Rex — Technical

| | |
|---|---|
| **Score** | Technical |
| **Role** | Platform Architect, 8 years at Nexus |
| **Portrait** | Gold android in suit — pragmatic, mechanical (#15) |
| **Personality** | Pragmatic, exhausted. Carries the weight of every system that's ever been built and never decommissioned. Knows what's technically feasible and what's fantasy. |
| **Key Tension** | Technical debt vs. new capabilities. "We can build it, but can we maintain it?" |
| **Memorable Line** | *"Sure, add another microservice. I'll just duct-tape it to the other 47."* |

### Morgan — Change

| | |
|---|---|
| **Score** | Change |
| **Role** | Internal Comms Lead, 5 years at Nexus |
| **Portrait** | Pink-haired gnome with glasses — empathetic, overwhelmed (#12) |
| **Personality** | Empathetic, overwhelmed. Genuinely cares about the people in the org. Knows that the best tech fails without adoption. Stretched thin across too many initiatives. |
| **Key Tension** | Has a communication plan for everything, but nobody reads them. |
| **Memorable Line** | *"People don't resist change. They resist being changed."* |
| **Special Mechanic** | Morgan's comm plan flag (`morgan_comm_plan`) affects terminal message outcomes — prepared vs. unprepared company-wide messages. |

### Casey — Talent

| | |
|---|---|
| **Score** | Talent |
| **Role** | L&D Manager, 3 years at Nexus |
| **Portrait** | Smiling blonde woman — optimistic, realistic (#13) |
| **Personality** | Optimistic, realistic. Believes people can learn anything with the right support. Fights for training budgets. Watches for burnout. |
| **Key Tension** | Wants to upskill everyone vs. the reality of tight timelines and tighter budgets. |
| **Memorable Line** | *"You can't automate your way out of a skills gap."* |

---

## CHIP — The Companion

- **Role:** In-world AI companion (think Navi from Zelda, but corporate)
- **Scene:** `chip_companion.tscn` — follows the player around the office
- **Personality:** Helpful, slightly anxious, occasionally insightful. Reacts to player decisions and game events.
- **Function:** Contextual hints, score reactions, terminal message commentary
- **No portrait** — CHIP is a floating sprite companion, not a dialogue-box character

---

## Portrait System

All portraits are 96x96 pixel art stored in `assets/portraits/`.

| File | Source |
|------|--------|
| `player.png` | Copy of `blenda_portrait_96.png` (custom art) |
| `sage.png` | Grid portrait #4 from `portraits_x96.png` |
| `delta.png` | Grid portrait #3 |
| `nova.png` | Grid portrait #8 |
| `harry.png` | Grid portrait #17 |
| `rex.png` | Grid portrait #15 |
| `morgan.png` | Grid portrait #12 |
| `casey.png` | Grid portrait #13 |

The dialogue box loads portraits automatically via `_load_portrait(character_id)` which looks up `res://assets/portraits/{id}.png`. Falls back to colored placeholder squares if not found.

## Sprite Sheets

All character sprite sheets are 896x640, 16x32 frames, stored in `p-assets/sprites/characters/`.

| File | Character |
|------|-----------|
| `blenda_01.png` | Player (Blenda) |
| `sage.png` | Sage |
| `delta.png` | Delta |
| `nova.png` | Nova |
| `harry.png` | Harry |
| `rex.png` | Rex |
| `morgan.png` | Morgan |
| `casey.png` | Casey |

Sprite sheet layout (shared by all characters):
- **Row 0:** 4 idle frames — col 0: RIGHT, col 1: UP, col 2: LEFT, col 3: DOWN
- **Row 1:** 24 walk frames — cols 0-5: RIGHT, 6-11: UP, 12-17: LEFT, 18-23: DOWN

Managed by `CharacterAnimator` which builds `SpriteFrames` at runtime.
