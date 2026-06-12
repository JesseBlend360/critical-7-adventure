#!/usr/bin/env bash
# Headless Web export for Critical 7.
# Usage:  tools/export_web.sh [debug|release]
# Output: build/web/index.html (+ supporting files)

set -euo pipefail

cd "$(dirname "$0")/.."

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
BUILD_TYPE="${1:-release}"
OUT_DIR="build/web"
OUT_FILE="$OUT_DIR/index.html"

if [[ ! -x "$GODOT" ]]; then
    echo "Godot not found at: $GODOT"
    echo "Set the GODOT env var to your Godot binary."
    exit 1
fi

mkdir -p "$OUT_DIR"

case "$BUILD_TYPE" in
    debug)   EXPORT_FLAG="--export-debug" ;;
    release) EXPORT_FLAG="--export-release" ;;
    *) echo "Unknown build type: $BUILD_TYPE (use debug|release)"; exit 1 ;;
esac

echo "Exporting Web ($BUILD_TYPE) → $OUT_FILE"
"$GODOT" --headless --path . "$EXPORT_FLAG" "Web" "$OUT_FILE"

echo
echo "Export complete. Files:"
ls -lh "$OUT_DIR"
echo
echo "Serve with:  tools/serve_web.py"
