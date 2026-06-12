# Critical 7 — Game Design v0.3 (Reorientation)

**Status:** Canonical design doc going forward. Supersedes the architecture in
`scene_system.md` (multi-scene model — abandoned) and the score-impact rules in
`decisions.md` (decisions now budget-only).

**Last Updated:** 2026-06-01

---

## Premise

The player is **Blenda**, newly responsible for an AI/data transformation at a
mid-sized company. She has 16 weeks (one quarter) to prepare for the
**Quarterly Business Review** — the boss fight, a presentation in front of the
board. The game teaches the Critical 7 dimensions of AI transformation
(Strategy, Data, Technical, Innovation, Change, Talent, Trust) by making each
of them mechanically distinct.

Target audience: visitors to the Blend website. Most will play once. The game
should feel light, the lesson should land regardless of outcome, and the
ending should make Blend's value proposition legible.

---

## The Three Orthogonal Resources

Every system in the game changes exactly one resource, and every resource has
exactly one input. This is the single most important architectural rule.

| Resource | What it changes | What changes it |
|---|---|---|
| **Critical 7 scores** | NPC reactions, available email choices, QBR defense options | *Conversations only* |
| **Budget** ($750K start) | Whether you can afford to send an email tonight | *Emails only* |
| **Time (weeks 1→16)** | When the QBR fires | The "Next Day" button on the terminal |

**Implication:** Decisions (now called *emails*) no longer touch the
Critical 7 at all. Conversations no longer cost budget or time. Each system is
clean and easy to balance.

---

## The Daily Loop

A day has three phases.

### 1. Morning — Walk & Talk

- Player wakes up in the reception area (bottom-center of the office) with a
  short briefing from CHIP: day number, budget remaining, any overnight news
  from yesterday's emails.
- Player walks the office. Each NPC has *one* meaningful conversation per day.
- Conversations are the only source of Critical 7 score changes.
- Conversations also unlock email "cards" available at the terminal that night
  and set flags that gate tomorrow's conversations.
- A real-time **day timer** is running. It pauses during dialogue or menus.
  See "Timer" below.

### 2. Evening — Terminal

- Player walks to Blenda's office (bottom-right) and interacts with her
  computer.
- Terminal shows the email cards unlocked today plus baseline ones. Each card
  has 1–3 tone variants gated by Critical 7 scores (see "Email Variants").
- Each variant costs budget and may set flags. **No score changes.**
- Player picks N cards (1–3), presses **SEND DAILY DIGEST**.
- A **SKIP DAY** option exists for broke or strategic players. CHIP nudges.

### 3. Night — Fade and Reset

- Screen fades to black.
- Week counter advances. Overnight flag effects resolve (NPC moods, locked
  doors opening, etc.).
- Fade back in: Blenda standing in the reception area. New day.

Loop until `current_week > 16` → QBR.

---

## The Day Timer

A real-time clock that gives the day its rhythm. It is the reason the office
map matters: geography becomes a cost.

### Rules

- **Runs** only while the player has movement control in the world.
- **Pauses** during dialogue, menus, status screen, terminal.
- CHIP speech bubbles do **not** pause it (no exploit).
- Visible HUD clock dims when paused so players feel the rule.

### Durations (subject to playtest)

| Difficulty | Day length |
|---|---|
| Easy | 5:00 |
| Medium | 3:30 |
| Hard | 2:30 |

- Last 30 seconds: ambient urgency — music shift, lights flicker, NPCs drift
  toward exits.
- Last 10 seconds: hard nudge — arrow points to Blenda's terminal.
- Time expires: Blenda's feet auto-walk toward the terminal. Player still has
  limited control but cannot reach further NPCs. Terminal opens with whatever
  is unlocked. Failing to make it to the terminal is **not** game over — you
  just have fewer options tonight.

### Implementation Notes

- Single `DayClock` autoload: `time_remaining`, `is_running`, `pause()`,
  `resume()`.
- Signals: `tick(seconds_left)`, `day_ending_soon`, `day_ended`.
- DialogueManager and any modal emits `opened` / `closed`. DayClock listens
  and pauses via a **reason stack** (push/pop) so nested pauses don't
  accidentally unpause.
- HUD clock: top-center, near existing budget bar.

### Friction Layer (the "annoying stuff")

Optional obstacles that make routing meaningful and themed to scores:

- **Hallway Chatter NPC** — generic coworker, ~5s of mashed dialogue
- **Printer jam** — interactable blocking a chokepoint
- **"Got a sec?" Slack ping** — modal pause but penalizes if dismissed
- **Coffee spill** — slow-tile cluster for a few seconds
- **Phil from Accounting** — patrolling NPC; cone-of-vision pull
- **CEO's assistant** — forced detour to Harry on certain triggers

High `change` score = fewer interruptions (Morgan's training stuck).
Low `trust` score = more "got a sec?" pings.

The friction layer is **optional polish**. Build the core loop without it
first.

---

## Conversations

Conversations are the only source of Critical 7 changes. Therefore every NPC
needs enough conversational depth to span the full 16 weeks.

### Per-NPC Bible

Each NPC has:
- A **score alignment** (their primary Critical 7 dimension)
- A **max points awarded** cap (their total contribution to that dimension's
  budget across the full game; ~60 points each is a reasonable starting cap)
- **Consistency anchors** — short factual assertions every line must respect
  (e.g., "Delta has been on the team 4 years", "Delta was burned by a failed
  migration"). Used by the LLM-variant validator.
- A **voice profile** — tone traits, signature phrases, taboo phrases.

### Conversation Availability

Conversations are gated by:
- Day number (e.g., available from day 3+)
- Flags set / not set
- Score thresholds
- `talked_to` history (first meeting vs nth visit)

A conversation has:
- `talk_seconds` — estimated real-time cost (for timer-aware planning &
  validator)
- `score_effects` — the Critical 7 delta this conversation grants
- `sets_flags` — flags raised on completion
- `unlocks_emails` — email card IDs that appear in tonight's terminal

### Volume

Hand-authoring 7 NPCs × ~16 days × ~3 branches each is ~300 scenes. This is
the primary reason the LLM-generation pipeline (see "Generated Variants"
below) exists.

---

## Emails (formerly "Decisions")

Emails are sent from the terminal at the end of each day. They burn budget
and set flags. **They do not change Critical 7 scores.**

### Card Shape

```jsonc
{
  "id": "email.reorg_data_team",
  "category": "data",
  "day_available_from": 3,
  "variants": {
    "confident": {
      "gate":  { "score_min": { "data": 15 } },
      "cost":  40000,
      "text":  "...",
      "sets_flags": ["data_team_aligned"]
    },
    "cautious": {
      "gate":  { "score_min": { "data": 8 } },
      "cost":  25000,
      "text":  "...",
      "sets_flags": ["data_team_meh"]
    },
    "snarky": {
      "gate":  { "score_max": { "data": 4 } },
      "cost":  5000,
      "text":  "Reply-all 'lol just vibes'",
      "sets_flags": ["data_team_chaos"]
    }
  }
}
```

### Why Variants Matter

- High-score runs unlock *competent* options. Players feel earned.
- Low-score runs unlock *snarky* options. Players feel entertained, not
  punished. Many will replay specifically to see the dumb branch.
- The chosen variant sets a flag that comes back to bite or help in
  tomorrow's conversations. **This is the loop:** conversations earn the
  right to make competent decisions; decisions reshape tomorrow's
  conversations.

### Migration from v0.2

The current `data/decisions.json` (30 entries) becomes the seed for emails.
All `impact` score deltas must be **stripped** — score effects move into
dialogue. `cost.budget` and `cost.time` are preserved (time becomes "this
counts toward the 16 weeks" only if we keep multi-day emails; default is
1 day = 1 email batch).

---

## The Quarterly Business Review (Boss Fight)

The QBR is structurally the daily loop's terminal phase, with the curtain
pulled back. Same UI primitives (gated multi-choice), wrapped in cinematic.

### Trigger

`current_week > 16` and player ends the day at the terminal. The terminal's
SEND button is replaced with **ATTEND THE QBR**.

### Cinematic Hallway

1. Fade to black, fade in at the **bottom** of the long hallway leading to
   the Grand Conference Room (top of the map).
2. Torches on the walls. Music shifts to low strings.
3. Player walks up. Camera tightens until only the hallway is visible —
   neither end of the office is on screen.
4. **During the obscured middle stretch**, NPCs are teleported from wherever
   they were into the conference room and seated/arranged behind the board.
5. Player reaches the conference room doors. Doors swing open. Wide shot:
   long table, board members seated, NPCs ringed behind them. Boss at the
   head of the table.
6. Blenda auto-walks to the podium at the front.

### The Lightning Round

5–7 slides. Each slide is a single question + 3 score-gated answers, with a
short per-slide timer.

```jsonc
{
  "topic": "data_strategy",
  "advocate": "delta",                 // their NPC appears beside the question
  "question": "Walk us through your data foundation.",
  "time_limit_seconds": 12,
  "choices": [
    { "gate": { "score_min": { "data": 20 } },
      "text": "Confident answer", "presentation": +3,
      "advocate_reaction": "proud" },
    { "gate": { "score_min": { "data": 10 } },
      "text": "Cautious answer", "presentation": +1,
      "advocate_reaction": "supportive" },
    { "gate": { "score_min": { "data":  0 } },
      "text": "Floundering answer", "presentation": -2,
      "advocate_reaction": "winces" }
  ],
  "teaching_beat": "Blend's view: data quality is a first-class deliverable, not an afterthought."
}
```

Per slide:
- Board member asks the question (text in the dialogue box).
- 3 choices shown; locked ones are visible but greyed (player sees what they
  *would* have unlocked at higher scores).
- Per-slide timer counts down. If it expires, the worst available option auto-
  selects with a flavored "[Blenda hesitates]" prefix.
- Advocate NPC reacts visibly. Tiny "+/- presentation" floats up.
- Teaching beat displays for 2–3 seconds before the next slide.

### Outcome

- Presentation meter (0–N across all slides) combines with Critical 7 averages
  to pick the ending tier. Existing 5 tiers (catastrophic / partial_failure /
  mixed / success / exceptional) remain.
- Summary screen shows:
  - Tier title, narrative, CHIP line
  - Critical 7 score bars + per-dimension summary
  - **"What could have been better"** — surfaces teaching beats from the 2
    lowest-scored slides. This is where Blend's value proposition lands.
  - Stats (budget spent, week reached, decisions made)
  - **Play Again** button → full reset → reception, day 1

---

## Scene Architecture

**One scene.** All gameplay happens in a single large scene
(`scenes/rooms/common_hub.tscn` for now; will likely be renamed to
`scenes/office.tscn` or similar). No teleporting between rooms.

The earlier multi-scene `SceneRouter` architecture (see deprecated
`scene_system.md`) was abandoned. The `SceneRouter` autoload and door
`target_scene` exports are unused but harmless and can be stripped when
convenient.

### Why Single-Scene

- Simpler to author and to reason about.
- The QBR cinematic actually requires the conference room to be in the same
  scene as the office — the "screen can only see the hallway" trick works
  because both ends exist in one map.
- Y-sort and lighting are easier to manage globally.

### Required Camera Setup

- `Camera2D` parented to Player.
- Limits configured to match the full map bounds so the camera doesn't show
  out-of-bounds when Blenda is at the edges.

---

## State System (Updated)

`GameState` tracks:

- `scores: Dictionary` — strategy, data, technical, innovation, change,
  talent, trust (int each). Changed *only* by conversations.
- `budget: int` — starts at $750K (medium). Burned *only* by emails sent.
- `current_week: int` — starts at 1, advances at end-of-day. QBR at >16.
- `current_day: int` — within the week, useful for fine-grained gating.
  (Optional; could also collapse week ≈ day for simplicity.)
- `flags: Array[String]` — set by conversations and by sent emails.
- `talked_to_today: Array[String]` — reset each morning.
- `talked_to_ever: Array[String]` — never reset.
- `emails_sent: Array[Dictionary]` — log of `{id, variant, day, cost}`.
- `dialogue_history: Dictionary` — last node per NPC.
- `presentation_score: int` — only populated during/after QBR.

Conditions evaluated against state: `talked_to`, `not_talked_to`, `flags`,
`not_flags`, `score_min`, `score_max`, `day_min`, `day_max`,
`email_sent`, `email_not_sent`.

### Game-Flow State Machine

```
boot → difficulty_picker → DAY_START
DAY_START → MORNING_BRIEFING → WALK_AND_TALK
WALK_AND_TALK → (timer expires OR player interacts with terminal) → TERMINAL
TERMINAL → (SEND or SKIP) → NIGHT_FADE → (week++ if not weekend, advance day)
NIGHT_FADE → DAY_START (if week ≤ 16) OR QBR_HALLWAY (if week > 16)
QBR_HALLWAY → QBR_ENTRY_CINEMATIC → QBR_LIGHTNING_ROUND → ENDING_SUMMARY
ENDING_SUMMARY → (Play Again) → boot
```

Budget reaching ≤ 0 mid-day: terminal still opens that night but with no
affordable emails. No instant game over. The QBR still fires at week 16 — a
broke run is its own kind of ending.

---

## Data Files (New / Updated)

| File | Role | Status |
|---|---|---|
| `data/dialogue/<npc>.json` | Per-NPC conversations. Now the **only** score source. | Existing, needs expansion to 16 days |
| `data/emails.json` | Email cards (replaces decisions.json). Budget + flags only. | New — migrate from decisions.json |
| `data/qbr_slides.json` | The lightning round slide deck (5–7 entries). | New |
| `data/npc_bibles.json` | Per-NPC voice profile, anchors, score caps. Used by LLM validator. | New |
| `data/story_manifest.json` | Story-wide budget caps, day schedule, validator config. | New |
| `data/endings.json` | 5 tiers + narratives. | Existing, keep |
| `data/chip_lines.json` | CHIP contextual lines. | Existing, keep |
| `data/terminal_messages.json` | Old terminal-message system. | Deprecate — merge into emails.json |

---

## Generated Variants (Future)

The point of the data-structure discipline above is to make the story
**machine-authorable**. The intended pipeline:

1. LLM proposes a `story_manifest.json` skeleton — premise, day schedule,
   conversation slots, email slots, QBR slide topics. **No text yet.**
2. **Validator** (Python script under `tools/`) checks:
   - Score budgets per dimension are reachable but not exceeded.
   - Per-NPC point caps respected.
   - Every gate references something reachable from day 1.
   - Every email is affordable given the budget curve.
   - Every QBR slide has at least the lowest-tier choice reachable from a
     worst-case run.
   - All 7 Critical 7 dimensions are covered by ≥1 QBR slide.
3. LLM fills conversation + email + slide text per-NPC, with the bible pinned.
4. Validator second pass: each generated line checked against the NPC's
   consistency anchors ("does this contradict any of these facts?").
5. Optional simulator: N greedy + N adversarial bot players run the variant,
   confirm endings distribute correctly.

Goal: hundreds of variants. Players replay because the story is different
each time but the lesson (Critical 7) is the same.

Stub the validator *now*, even before any generation, to enforce budgets on
the hand-authored content. When the validator stays green on hand content,
swapping in generated content is mostly free.

---

## Migration Path from Current Code

Cheapest-first order. Each step playable.

1. **Strip score effects from `decisions.json`.** Rename file to
   `emails.json`. Mechanical edit. Audit dialogue to confirm no NPC was
   secretly depending on decision-driven score deltas.
2. **`DayClock` autoload + HUD clock + dialogue/menu pause plumbing.** Small,
   isolated change. ~20 minutes to feel.
3. **Day-end cinematic.** Terminal SEND button → ColorRect fade → respawn at
   reception Marker2D → week++. ~30 lines of GDScript.
4. **Email variants UI.** Terminal already shows a list; extend each entry to
   show 1–3 gated tone variants.
5. **Conversation expansion.** Per-NPC dialogue grows from "first meeting +
   return visit" to "day-N gated" structure. This is the big content lift.
6. **QBR rewrite.** Replace the current action-budget boss fight with the
   lightning-round slide system.
7. **Validator tool.** Python script under `tools/validate_story.py` that
   loads the story manifest and checks all the invariants above.
8. **LLM generation pipeline.** Last, only once the validator is mature.

---

## What's Explicitly Out of Scope

- Multi-scene transitions (`SceneRouter`, scene-changing doors).
- Action-budget boss fight (replaced by lightning round).
- Score impacts on emails (decisions).
- Time costs on emails (default: 1 email batch per day).
- Player-room (Blenda's office) evolving over time (cool idea, parked).

---

## Glossary

- **Critical 7** — the 7 dimensions of AI transformation: Strategy, Data,
  Technical, Innovation, Change, Talent, Trust.
- **Email / Card** — a player action sent from the terminal at end of day.
  Burns budget, sets flags. Formerly "decision."
- **Conversation** — dialogue with an NPC during the day. Only source of
  Critical 7 score changes.
- **Variant** — a tone version of an email (confident/cautious/snarky) or a
  full generated story variant.
- **QBR** — Quarterly Business Review. The boss fight at week >16.
- **Lightning Round** — the 5–7-slide gated-choice format used in the QBR.
- **Teaching Beat** — a short in-character line during the QBR that surfaces
  Blend's view on a Critical 7 dimension. Also shown on the summary screen.
