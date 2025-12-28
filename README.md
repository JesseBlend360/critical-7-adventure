# Critical 7

A top-down 2D AI strategy adventure game built in Godot 4.5. Walk around an office and talk to NPCs.

## Requirements

- Godot 4.5+

## Running the Game

```bash
# Open in Godot editor
godot --path . --editor

# Run directly
godot --path .
```

## Controls

| Action | Keys |
|--------|------|
| Move | WASD / Arrow keys |
| Interact | E / Space |

## Project Structure

```
scenes/
  main.tscn          # Main game scene
  player.tscn        # Player character
  npc.tscn           # Reusable NPC template
  ui/dialogue_box.tscn
scripts/
  main.gd            # Scene setup
  player.gd          # Movement and interaction
  npc.gd             # NPC interaction zones
  dialogue_box.gd    # Dialogue UI
  game_manager.gd    # Global state (autoload)
data/
  dialogue.json      # NPC dialogue content
assets/
  sprites/Tilemap/   # Kenney Tiny Dungeon tileset (16x16)
```

## License

TBD