# Godot Chess (Web)

A chess game written in GDScript for Godot 4.7, exported to the browser (HTML5/WebAssembly).

**Play it:** https://justintphan.github.io/play-chess/

- Modes: **1 vs 1** (local, same device) and **1 vs Bot** (Easy, Medium, Hard; play White, Black or random)
- Full rules: castling, en passant, promotion (with a piece picker), check, checkmate, stalemate,
  50-move, threefold repetition, insufficient material
- Move list in SAN, Undo, Restart, Flip board, tap-to-move and drag-and-drop
- Layout adapts to iPad portrait and landscape and to larger screens (board capped at 900 px)
- No threads, so no COOP/COEP headers are needed: any static host works

## Requirements

Godot 4.7.x with the matching Web export templates installed.

    GODOT=/Applications/Godot.app/Contents/MacOS/Godot

## Run in the editor / from the CLI

    $GODOT --path .            # runs the game
    $GODOT --headless --path . --import   # (re)import assets, needed once after a fresh clone

## Tests

    $GODOT --headless --path . -s res://tests/run_tests.gd                # everything
    $GODOT --headless --path . -s res://tests/run_tests.gd -- perft       # perft only (also: rules, bot)
    $GODOT --headless --path . res://tests/smoke_ui.tscn                  # UI smoke test

## Export for the web

    mkdir -p build/web
    $GODOT --headless --path . --export-release "Web" build/web/index.html

Output: `build/web/index.html`, `.js`, `.wasm`, `.pck` and icons.

## Serve locally

    python3 -m http.server 8080 -d build/web

Open http://localhost:8080. To test on an iPad on the same Wi-Fi, open `http://<your-mac-ip>:8080`
in Safari (use "Add to Home Screen" for full-screen mode).

To deploy, upload the contents of `build/web/` to any static host (GitHub Pages, itch.io, Netlify...).

## Publish to GitHub Pages

The live site is served from the `gh-pages` branch, which holds only the exported files.
After exporting, publish a new version with:

    ./publish.sh

## Bot levels

| Level | Search | Notes |
|---|---|---|
| Easy | 1 ply, no quiescence | 35% random moves, plus +-150 cp noise |
| Medium | 2 ply + quiescence, 1 s cap | +-30 cp noise |
| Hard | iterative deepening to 5 ply + quiescence + transposition table, 2 s cap | depth reached depends on device speed |

The search runs on the main thread in small time slices so the page stays responsive.

## Credits

Piece artwork: the "Cburnett" set by Colin M. L. Burnett (Wikimedia Commons), licensed under
GFDL / BSD / GPL-2.0+ and CC BY-SA 3.0. See `assets/pieces/LICENSE.md`.

The app logo (`icon.svg`) is original artwork made for this project.
