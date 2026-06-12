# Critical 7 — Web (HTML5) Export Pipeline

**Last Updated:** 2026-06-11

This project exports to HTML5 so the game can be viewed and controlled in a
browser (including via the Claude Code preview tools). The export uses Godot's
**Compatibility renderer** (WebGL 2 / GLES3), which the project is already
configured for.

---

## Quick start

```bash
# 1. Export (≈30s). Writes build/web/index.html + supporting files.
tools/export_web.sh release        # or: tools/export_web.sh debug

# 2. Serve it locally with the headers Godot needs.
tools/serve_web.py                 # http://127.0.0.1:8060/
```

Then open <http://127.0.0.1:8060/> in a browser, or let the Claude preview
tools attach to the running server.

---

## Files

| File | Purpose |
|------|---------|
| `export_presets.cfg` | Godot export preset named **"Web"**. No-threads release variant. Output → `build/web/index.html`. |
| `tools/export_web.sh` | Headless export wrapper. `tools/export_web.sh [debug\|release]`. Honors `$GODOT` env var for the binary path. |
| `tools/serve_web.py` | Minimal Python HTTP server on port 8060 that sets the required headers and disables caching. |
| `.claude/launch.json` | Has a `critical-7: web (godot html5 export)` entry so the preview tooling can start the server on 8060. |

`build/web/` is git-ignored (the repo's `.gitignore` already excludes
`build/`).

---

## Why the no-threads variant

Godot's default Web export uses `SharedArrayBuffer` for threading, which
browsers only enable when the page is served with **cross-origin isolation**
headers:

- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: require-corp`

We export with `variant/thread_support=false` (the `web_nothreads_release`
template) so the game runs on any plain HTTP server without those headers.
This game is dialogue-driven and not CPU-bound, so single-threaded is fine.

`tools/serve_web.py` still sends the isolation headers anyway — so if you ever
flip `thread_support` back on, the server doesn't need to change.

---

## Requirements

- **Godot 4.6.x** at `/Applications/Godot.app/Contents/MacOS/Godot` (override
  with the `GODOT` env var).
- **Web export templates** installed for the matching Godot version
  (Editor → Manage Export Templates). Already present for 4.6.1 on this machine.

---

## Output size

Roughly:

- `index.wasm` — ~36 MB (the Godot engine; constant, cacheable)
- `index.pck` — ~8 MB (the game's packed assets)
- everything else — small (~340 KB)

First load fetches the wasm; subsequent loads are cached by the browser
(during dev we disable caching server-side so re-exports show up immediately).

---

## Controlling the game in a browser

- **Viewing / screenshots** — works fully.
- **Mouse** — click coordinates map directly onto the canvas.
- **Keyboard** — WASD / Space / Tab etc. are delivered as standard DOM key
  events to the canvas. Focus is auto-grabbed on start
  (`html/focus_canvas_on_start=true`).

There is **no hot reload** — after changing a script or scene in Godot you must
re-run `tools/export_web.sh` and refresh the browser.

---

## Known issues (as of 2026-06-11)

The first successful export surfaced runtime errors that also affect the
desktop build — they are **not** web-specific, but they're very visible in the
browser (blank map, NPCs render as shadows only):

```
ERROR: Cannot get class ''.
WARNING: Node BookshelfTall / BookshelfTall2 of type '' cannot be created.
ERROR: There is no animation with name ''.
ERROR: There is no animation with name 'close'.
```

Likely causes to investigate:

- **Bookshelf furniture scenes** reference a script/class that isn't being
  resolved in the export (empty type string → placeholder node).
- **Door** `AnimatedSprite2D` can't find its `close` animation at startup.
- **CharacterAnimator** is building empty `SpriteFrames` for NPCs, so their
  sprites don't render (only the `BounceAnimator` shadow shows).
- **TileMap textures invisible** — possibly tied to the oversized
  `Interiors_16x16.png` (256×17024) exceeding the WebGL max texture size; see
  the split strips `Interiors_16x16_partN.png`. Any tile source still pointing
  at the full sheet will fail to upload and render blank.

These are tracked as the next work item: **fix textures / asset loading in the
web build.**
