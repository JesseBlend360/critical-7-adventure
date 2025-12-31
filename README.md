# Critical 7

A top-down 2D AI strategy adventure game built in Godot 4.5. Walk around an office, talk to NPCs, and navigate the challenges of leading an AI initiative.

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
| Select dialogue choice | 1 / 2 / 3 or click |
| Status screen | Tab |

## Features

### Core Gameplay
- **Budget & Timeline** - Manage $750K over 16 weeks to deliver Project Atlas
- **Critical 7 Scores** - Track 7 key metrics: Strategy, Data, Technical, Innovation, Change, Talent, Trust
- **Decision System** - 20 major decisions with visible costs (budget/time) and hidden score impacts

### Dialogue
- **Branching dialogue system** - NPCs have dynamic conversations with multiple paths
- **Skill checks** - Some choices require minimum scores (shown as locked with requirements)
- **State tracking** - Your choices affect scores, flags, and relationships
- **Conditional dialogue** - Choices appear/hide based on who you've talked to and what you've done

### UI
- **HUD** - Always-visible budget bar and week counter
- **Status Screen** - Press Tab to view Critical 7 scores and project trajectory
- **CHIP Companion** - Snarky AI assistant with contextual commentary
- **Ending Screen** - 5 possible endings based on your performance

### Polish
- **Pushable NPCs** - NPCs use physics and can be nudged around
- **Bouncy animations** - Characters have idle bob and walking bounce animations with shadows

## Project Structure

```
scenes/
  main.tscn              # Main game scene
  player.tscn            # Player character
  npc.tscn               # Reusable NPC template
  chip.tscn              # CHIP companion sprite
  ui/
    dialogue_box.tscn    # Dialogue UI with choices
    hud.tscn             # Budget/week display
    status_screen.tscn   # Critical 7 scores (Tab menu)
    ending_screen.tscn   # End game summary
scripts/
  player.gd              # Movement and interaction
  npc.gd                 # NPC interaction and wandering
  dialogue_box.gd        # Dialogue UI with locked choice display
  dialogue_manager.gd    # Conversation flow (autoload)
  game_state.gd          # State, budget, timeline (autoload)
  decision_manager.gd    # Decision logic (autoload)
  game_manager.gd        # Legacy signals (autoload)
  hud.gd                 # HUD controller
  status_screen.gd       # Status screen controller
  chip.gd                # CHIP companion logic
  ending_screen.gd       # Ending calculation and display
  bounce_animator.gd     # Bouncy animation component
data/
  decisions.json         # 20 major decisions with costs/impacts
  chip_lines.json        # CHIP contextual dialogue
  endings.json           # Ending text by tier
  dialogue/              # Per-NPC dialogue JSON files
    sage.json
    delta.json
    nova.json
    harry.json
assets/
  sprites/Tilemap/       # Kenney Tiny Dungeon tileset (16x16)
docs/
  game_state_and_dialogue.md  # System design spec
```

## NPCs

- **Harry Vance** - CEO & Founder, skeptical veteran who's seen AI projects fail before
- **Sage** - Strategy consultant, focuses on business cases and ROI
- **Delta** - Data engineer, concerned with data quality and pipelines
- **Nova** - ML engineer, loves prototyping but struggles with production

## Credits

- **Tileset**: [LimeZu](https://limezu.itch.io/) (@lime_px) - Modern interiors tileset (proprietary, not included in repo)
- **Public Tileset**: [Kenney](https://kenney.nl/) - Tiny Dungeon (CC0)

## License

TBD
