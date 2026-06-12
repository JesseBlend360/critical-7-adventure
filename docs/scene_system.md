# Critical 7 — Room & Scene System

> **⚠️ DEPRECATED (2026-06-01).** The multi-scene Zelda-style architecture
> described here was abandoned in favor of a single-scene office map. The
> `SceneRouter` autoload, door `target_scene` exports, and per-room scene
> files are unused — left in place but slated for removal.
>
> See **[`game_design_v0.3.md`](game_design_v0.3.md)** for the current
> architecture. This file is kept as historical reference for the spawn-point
> /transition pattern in case multi-scene is revisited.

**Last Updated:** 2026-04-15

---

## Overview

The game uses a Zelda-style multi-scene architecture. The world is split into:

- A **boot scene** (`scenes/main.tscn`) that shows the difficulty picker at game start
- A **common hub** room (`scenes/rooms/common_hub.tscn`) — the "outdoors" area: cube farm, break room, lobby, bathroom
- **Per-character interior rooms** (one per Critical 7 aspect) — planned, not yet built
- A **boss room** — the Grand Conference Room, where the Board Presentation happens at week 16+

Only one room scene is active at a time. Player state, scores, flags, budget, and timeline persist across transitions via autoload singletons. UI and companion nodes also persist as autoloads so they don't have to be re-authored per room.

---

## Architecture

### Autoloads (registered in `project.godot`)

Loaded in order at engine startup. Earlier autoloads can be referenced by later ones.

| Autoload | Path | Type | Role |
|----------|------|------|------|
| `GameManager` | `scripts/game_manager.gd` | Script | Legacy flag holder (`dialogue_active`) |
| `GameState` | `scripts/game_state.gd` | Script | Central state: scores, budget, week, flags, talked_to, decisions |
| `DialogueManager` | `scripts/dialogue_manager.gd` | Script | Conversation flow, JSON loading, condition evaluation |
| `DecisionManager` | `scripts/decision_manager.gd` | Script | Decision costs/effects, ending calculation |
| `FloatingTextManager` | `scripts/floating_text_manager.gd` | Script | Spawns floating score text, parents it to current scene |
| `SceneRouter` | `scripts/scene_router.gd` | Script | Scene transitions + spawn-point handoff |
| `PersistentUI` | `scenes/ui/persistent_ui.tscn` | Scene | Wraps DialogueBox, HUD, StatusScreen, EndingScreen |
| `ChipCompanion` | `scenes/chip_companion.tscn` | Scene | Companion that follows the player across scenes |
| `BossFight` | `scripts/boss_fight.gd` | Script | End-game Board Presentation sequence |

### What lives in scenes vs autoloads

**In each room scene:**
- Player (CharacterBody2D) + Camera2D child
- Room-specific NPCs
- TileMapLayer(s) for the room's tiles
- Interactables (doors, terminal, furniture, readables)
- At least one `SpawnPoints/<Name>` Marker2D (see below)

**In autoloads only (never in room scenes):**
- UI layers (dialogue, HUD, status, ending)
- CHIP companion
- Boss fight controller
- All `Manager`/`State` singletons

---

## SceneRouter

`scripts/scene_router.gd` — the transition API.

### Public API

```gdscript
# Transition to another room.
SceneRouter.go_to("res://scenes/rooms/war_room.tscn", "from_hallway")

# Called by Player._ready() to position itself in the new scene.
SceneRouter.get_spawn_position(fallback: Vector2) -> Vector2
```

### Fields

- `pending_spawn_id: String` — spawn ID the next `_ready` should target. Set by `go_to()`, read by `Player._ready()`.
- `previous_scene_path: String` — path of the scene we just came from (for "back" buttons or debugging).

### Signals

- `scene_changing(from_path, to_path)` — emitted before `change_scene_to_file`
- `scene_changed(to_path)` — emitted one frame after the new scene becomes current

### Internal flow

```
go_to(path, spawn_id):
  pending_spawn_id = spawn_id
  scene_changing.emit(...)
  get_tree().change_scene_to_file(path)   # frees old scene, loads new one
  await process_frame
  scene_changed.emit(path)
```

---

## Spawn Points

Each room scene must have at least one spawn point so the player has somewhere to appear when arriving via `SceneRouter`.

### Authoring

1. Add a `Marker2D` node to the scene (convention: group them under a `SpawnPoints` Node2D parent).
2. Assign it to the `"spawn_point"` group.
3. Add a metadata entry `spawn_id` (String) — must be unique within the scene.

Example from `common_hub.tscn`:

```gdscript
[node name="SpawnPoints" type="Node2D" parent="."]

[node name="Default" type="Marker2D" parent="SpawnPoints" groups=["spawn_point"]]
position = Vector2(380, 300)
metadata/spawn_id = "default"
```

### Lookup rules (`SceneRouter.get_spawn_position`)

1. Exact match: marker with `spawn_id == pending_spawn_id`
2. Fallback: marker with `spawn_id == "default"`
3. Last resort: first marker in the `spawn_point` group
4. If none found: returns the caller's supplied fallback Vector2 and logs a warning

### Player snap

`scripts/player.gd` — at the end of `_ready()`:

```gdscript
func _apply_spawn_point() -> void:
    var router := get_node_or_null("/root/SceneRouter")
    if router == null:
        return
    var spawn_pos: Vector2 = router.get_spawn_position(global_position)
    if spawn_pos != Vector2.ZERO:
        global_position = spawn_pos
```

The guard means you can open a room scene directly in the editor and run it without autoloads — the player just stays where the scene was authored.

---

## Doors

`scripts/door.gd` handles both cosmetic doors (open/close animation only) and scene-transition doors.

### Exports

| Export | Type | Meaning |
|--------|------|---------|
| `door_sprite_sheet` | Texture2D | 5-frame 16×48 sheet, animated closed→open |
| `is_open` | bool | Initial state |
| `required_flag` | String | If set, door is locked until this GameState flag is set |
| `locked_message` | String | Floating text shown when interacting with a locked door |
| `target_scene` | `*.tscn` path | If set, interact transitions through SceneRouter instead of toggling |
| `target_spawn` | String | Spawn ID in the target scene (default: `"default"`) |
| `animate_before_transition` | bool | Play the open animation before changing scene (nicer, ~0.3s) |

### Authoring a scene-transition door

1. Place a Door instance in the origin scene. In the inspector:
   - Set `target_scene` to the destination `.tscn`
   - Set `target_spawn` to a spawn ID that exists in the destination scene
2. In the destination scene, add a matching spawn point with the same `spawn_id`, and a return door whose `target_scene` points back.

Example: the hallway door in `common_hub.tscn` leading to the War Room.

```
common_hub.tscn — Door "WarRoomDoor":
  target_scene = "res://scenes/rooms/war_room.tscn"
  target_spawn = "from_hub"

war_room.tscn:
  SpawnPoints/FromHub (Marker2D, group="spawn_point", spawn_id="from_hub")
  Door "ExitToHub":
    target_scene = "res://scenes/rooms/common_hub.tscn"
    target_spawn = "war_room_return"

common_hub.tscn:
  SpawnPoints/WarRoomReturn (Marker2D, group="spawn_point", spawn_id="war_room_return")
```

### Locked doors

Works orthogonally to transitions. If `required_flag` is set and `GameState.has_flag(required_flag)` is false, the door shows floating `locked_message` text and ignores interaction. Use this for Harry's office, the Grand Conference Room, and any late-game secret rooms.

---

## PersistentUI

`scenes/ui/persistent_ui.tscn` — a lightweight wrapper scene that instances the four shared UI CanvasLayers:

```
PersistentUI (Node)
├── DialogueBox   (instance of scenes/ui/dialogue_box.tscn)
├── HUD           (instance of scenes/ui/hud.tscn)
├── StatusScreen  (instance of scenes/ui/status_screen.tscn)
└── EndingScreen  (instance of scenes/ui/ending_screen.tscn)
```

Registered as an autoload, so these UI nodes exist once for the whole game and survive every scene change. Each UI node's script hooks into the existing `GameState` / `DialogueManager` signals during its `_ready()` — no code had to change when these were promoted to autoloads.

---

## CHIP Companion

Autoloaded from `scenes/chip_companion.tscn`. Lives at `/root/ChipCompanion` and is visible in all room scenes.

Scene-change handling: `_process` validates the player reference each frame via `is_instance_valid(player)`. When the player is freed (scene change), CHIP re-acquires the new scene's player and snaps to it instead of lerping across the map.

The first-meeting intro line is guarded by an `_intro_shown` bool and only fires after a valid player exists — so it doesn't fire while the boot scene is showing the difficulty picker.

---

## BossFight

Autoloaded from `scripts/boss_fight.gd`. Lives at `/root/BossFight`. Hooks into `GameState.game_over` and intercepts `"time_expired"` to start the Board Presentation sequence instead of the normal ending.

**Known assumption (tech debt):** `boss_fight.gd` currently looks up `get_tree().current_scene.get_node_or_null("NPCs")` to find the list of NPCs. This assumes the boss fight starts while the player is in a scene that has an `NPCs` node — true today because all NPCs live in `common_hub.tscn`. When NPCs are distributed across per-character rooms, this needs to become data-driven (objectives reference NPC IDs; the boss fight directs the player to visit each room).

---

## How to add a new room

1. **Create the scene**
   - Easiest start: duplicate `scenes/rooms/common_hub.tscn` as `scenes/rooms/<room_name>.tscn` and rename the root node.
   - Strip NPCs / furniture / doors you don't need.
   - Paint the TileMapLayer with the room's tiles.

2. **Required nodes**
   - `Player` instance + `Camera2D` as its child
   - At least one `Marker2D` in group `spawn_point` with metadata `spawn_id`
   - Collision walls (via TileMapLayer physics or StaticBody2D nodes) so the player can't walk out

3. **Wire up the doors**
   - In the hub (or wherever you enter from), pick a door and set `target_scene` + `target_spawn`.
   - Inside the new room, add a return door pointing back, and a matching spawn point for the return.

4. **Add the NPC**
   - Drop a `NPC` instance, set `npc_id` and `npc_sprite`.
   - Make sure `data/dialogue/<npc_id>.json` exists.

5. **Optional: lock the door**
   - Set `required_flag` on the hub-side door and set that flag somewhere appropriate (e.g. a plot gate elsewhere).

---

## Scene-list reference

| Path | Role |
|------|------|
| `scenes/main.tscn` | Boot scene (difficulty picker) |
| `scenes/rooms/common_hub.tscn` | The office common area (lobby + cubes + break room) |
| `scenes/rooms/war_room.tscn` | Sage's room — **planned** |
| `scenes/rooms/data_pit.tscn` | Delta's room — **planned** |
| `scenes/rooms/platform_ops.tscn` | Rex's room — **planned** |
| `scenes/rooms/sandbox.tscn` | Nova's room — **planned** |
| `scenes/rooms/comms_bay.tscn` | Morgan's room — **planned** |
| `scenes/rooms/learning_annex.tscn` | Casey's room — **planned** |
| `scenes/rooms/harry_office.tscn` | Harry's corner office — **planned** |
| `scenes/rooms/grand_conference.tscn` | Boss room (Board Presentation) — **planned** |
| `scenes/rooms/blenda_office.tscn` | Player's own office (decision desk, optional evolving clutter) — **planned** |

---

## Running a single room in isolation

Room scenes are authored to be runnable on their own in the editor:

- The player's `_apply_spawn_point()` no-ops cleanly if `SceneRouter` is missing (so the player stays where the scene placed them).
- Autoloads (GameState, DialogueManager, etc.) are still active when running a scene via F6, so dialogue and score tracking work.
- Doors that have a `target_scene` will attempt the real transition, so test either without `target_scene` set or be OK with Godot changing to that scene.

---

## Notes / conventions

- **Scene paths** are always written full `res://scenes/rooms/<name>.tscn` — no relative paths.
- **Spawn IDs** use `snake_case` and should read like prepositions from the origin: `from_hub`, `from_war_room`, `from_hallway`.
- **Door naming** mirrors the destination: `WarRoomDoor` (hub side), `ExitToHub` (room side).
- **Group name** for spawn points is literally `"spawn_point"` (singular), matching `SceneRouter.get_nodes_in_group`.
- **Autoload order matters** — `PersistentUI`, `ChipCompanion`, and `BossFight` depend on `GameState` / `DialogueManager` / `DecisionManager` being initialized first. Don't reorder autoloads without thinking about this.
