#!/usr/bin/env bash
# Export the Web build and publish it to the gh-pages branch (GitHub Pages).
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
REMOTE="$(git -C "$ROOT" remote get-url origin)"

mkdir -p "$ROOT/build/web"
"$GODOT" --headless --path "$ROOT" --export-release "Web" build/web/index.html

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -R "$ROOT/build/web/." "$TMP/"
rm -f "$TMP"/*.import
touch "$TMP/.nojekyll"

git -C "$TMP" init -q -b gh-pages
git -C "$TMP" add -A
git -C "$TMP" -c user.name="$(git -C "$ROOT" config user.name)" \
	-c user.email="$(git -C "$ROOT" config user.email)" \
	commit -q -m "Publish web build from $(git -C "$ROOT" rev-parse --short HEAD)"
git -C "$TMP" push -f "$REMOTE" gh-pages
echo "Published. GitHub Pages will update in a minute or two."
