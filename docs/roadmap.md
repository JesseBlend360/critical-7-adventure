# Critical 7 — Roadmap

## Completed

### v0.1 — Prototype (DONE)
- Player movement, office environment, NPC interaction, dialogue system
- See [PRD v0.1](prd_v0.1_prototype.md)

### v0.2 — Decisions & Game Loop (DONE)
- Decision system, budget/timeline, Critical 7 scores, HUD, status screen
- CHIP companion, ending system, boss fight
- All 7 NPCs, 30 decisions, 5 ending tiers
- Terminal system, interactables
- Character animation system, portraits, pixel art HUD
- See [PRD v0.2](prd_v0.2_decisions.md)

---

## v0.3 — Reorientation (IN PROGRESS)

Major design reorientation. See [`game_design_v0.3.md`](game_design_v0.3.md)
for the full spec. Headline changes:

- **Three orthogonal resources.** Conversations change Critical 7; emails
  burn budget; the "Next Day" button advances weeks. No system touches more
  than one resource.
- **Daily loop.** Morning walk-and-talk → evening terminal → fade to next
  day. Real-time day timer pauses during dialogue/menus.
- **Decisions → Emails.** `data/decisions.json` migrates to
  `data/emails.json`. Score impacts stripped; budget + flags only. Each
  email has 1–3 tone variants (confident / cautious / snarky) gated by
  Critical 7 scores.
- **Boss fight rewrite.** Action-budget boss fight replaced with a 5–7-slide
  "lightning round" QBR — same gated-choice UI as the terminal, with
  per-slide timers, advocate NPC reactions, and per-slide teaching beats
  surfacing Blend's value proposition.
- **Single-scene architecture.** Multi-scene `SceneRouter` work is
  abandoned. Everything lives in one office map; the QBR hallway cinematic
  teleports NPCs to the conference room while the screen can only see the
  hallway.
- **Story-as-data.** Build out `story_manifest.json` + validator to make
  hundreds of LLM-generated story variants feasible.

### Tasks (cheapest-first order)

- [x] Strip score effects from `data/decisions.json`; rename → `emails.json`
      *(score effects stripped; rename deferred)*
- [x] `DayClock` autoload + HUD clock + dialogue/menu pause plumbing
- [x] Day-end cinematic: terminal SEND → fade → respawn at reception
- [x] Day clock shows virtual office time (Mon 8 AM → Fri 5 PM, 45 ticks/week)
- [x] Auto-end-of-week at Fri 5 PM
- [x] QBR-pending mode: clock stops, HUD shows "🎤 QBR", player walks to
      conference room to trigger the boss fight
- [x] Score-grinding fix (`apply_effects_once`)
- [x] Conversation cooldown via per-choice hide + "[Leave]" idle fallback
- [x] Terminal-options notification toasts
- [ ] Email variants UI (3 gated tone options per card)
- [ ] Per-NPC dialogue expansion to day-N gated structure
- [ ] QBR lightning-round rewrite (replaces action-budget boss fight) — see
      polish list below
- [ ] `tools/validate_story.py` — story-budget and reachability validator
- [ ] (Later) LLM generation pipeline for story variants
- [ ] (Later) Friction layer — hallway chatter, printer jams, "got a sec?" pings

### QBR rewrite — visual & cinematic polish

These are the things the playtest revealed as "good enough for test, not for
ship." Bundle with the lightning-round mechanics rewrite:

- [ ] **Hidden teleport.** NPCs are currently visibly tweened from the
      common area to the player's position once the QBR fires. Should
      instead snap silently *while the camera is fully inside the long
      hallway* (no office or conference room visible), so when Blenda
      reaches the room everyone is already in place. Camera-bounds /
      framing logic needed for the hallway segment.
- [ ] **Conference-room props.** Long meeting table, chairs, a podium
      or screen at the front. Currently the conference room is an
      empty walled area.
- [ ] **NPC sitting state.** Sprite frames + an AnimatedSprite2D
      "sit" state per NPC. Boss fight should leave them seated (not
      standing) and remove the wandering loop while seated.
- [ ] **Boss-fight position offsets** (currently in `boss_fight.gd`,
      `npc_offsets`) should map to chair positions around the table
      rather than a free-floating board layout.
- [ ] **Door-driven trigger** instead of a y-threshold poll in
      `DayClock._check_qbr_walkup`. A dedicated conference-room door
      Area2D that fires `game_over("time_expired")` on enter would be
      cleaner and easier to playtest.

### Known Bugs / UI Debt

- [x] **Score-effect grinding.** ~~Conversations with score deltas can be
      re-triggered to award the same bonus multiple times.~~ Fixed via
      `GameState.apply_effects_once(key, effects)`. Dialogue effects are
      now keyed by `node:<npc>:<node_id>` and `choice:<npc>:<node_id>:<index>`
      and recorded in `GameState.applied_effect_keys` (cleared by `reset()`).
- [ ] **HUD virtual-time overlap.** The "Mon 8:00 AM" clock label overlaps
      the WeekPanel box on the HUD. Holding off on a fix — full HUD/UI
      rework is planned once the core loop is locked in.
- [ ] **NPCs walk into walls.** Idle wandering in `scripts/npc.gd` picks a
      random direction and walks until the wander timer expires, so NPCs
      frequently mash into walls/furniture. Possible fixes: raycast/probe
      ahead before committing to a direction, switch to navigation regions,
      or define per-NPC wander rect bounds. Low priority but visually
      distracting.

### Cleanup (low priority)

- [ ] Remove unused `SceneRouter` autoload + door `target_scene` exports
- [ ] Rename `scenes/rooms/common_hub.tscn` → `scenes/office.tscn`
- [ ] Configure Camera2D limits to match full office bounds

---

## Up Next (carried over from v0.2)

### Level Population & Environment
- [ ] Map out furniture sprites from `p-assets/sprites/modern_office.png`
- [ ] Create furniture scenes with correct region rects and collisions
- [ ] Populate office with desks, bookshelves, plants, equipment, etc.
- [ ] Prototype scenes exist in `scenes/furniture/` — duplicate and adjust region_rect/collision

### 2D Lighting & Shadow System
Add atmospheric lighting using Godot 4.3+ 2D light system. Reference video covers the full pipeline.

**Phase 1 — Basic Lighting**
- [ ] Add CanvasModulate to main scene for ambient darkness
- [ ] Add PointLight2D nodes for key light sources (overhead lights, desk lamps, monitors, windows)
- [ ] Use light textures or gradients for different light types
- [ ] Set up Light Masks and Z-index to control which objects are lit

**Phase 2 — Shadows & Occluders**
- [ ] Enable shadows on lights (`shadow_enabled`)
- [ ] Add LightOccluder2D to walls and large furniture
- [ ] Add occlusion layer to TileMap for automated wall shadow casting
- [ ] Tune shadow smoothness with PCF filtering
- [ ] Use Clockwise/Counterclockwise culling modes for granular edge control

**Phase 3 — Normal & Specular Maps (Polish)**
- [ ] Use Laigter (free tool) to generate normal and specular maps from existing sprites
- [ ] Create CanvasTexture resources combining diffuse + normal + specular
- [ ] Apply to character sprites and key furniture for faux-3D look
- [ ] Adjust light height to tune reflection appearance

**Notes:**
- Shadows require LightOccluder2D + OccluderPolygon2D per object (separate from collision shapes)
- Walls and large furniture are highest priority for occluders; small items can skip
- TileMap occlusion layer handles walls automatically once configured
- Normal/specular maps are pure polish — skip if time-constrained

---

## Backlog

### Decision Log View
- [ ] Build standalone `decision_log.tscn` showing chronological decision history
- [ ] Accessible from status screen

### Web Export
- [ ] Test HTML5 export via Compatibility Renderer
- [ ] Fix any web-specific issues

### Sound & Music
- [ ] Background music (office ambience, tense moments)
- [ ] SFX: footsteps, dialogue blips, decision chimes, CHIP sounds
- [ ] Boss fight music

### Save System
- [ ] Save/load game state to file
- [ ] Auto-save at key milestones

### Playtest & Balance
- [ ] Balance decision costs and score impacts
- [ ] Tune budget/timeline pacing
- [ ] Verify all 5 endings are reachable
- [ ] Test all dialogue branches and conditions
