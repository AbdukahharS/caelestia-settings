#!/usr/bin/env bash
# Recreates the symlinks into the system-installed Caelestia shell QML tree.
# Run once after cloning, and again if the caelestia-shell package path moves.
set -euo pipefail

cd "$(dirname "$0")/.."

CAELESTIA_DIR="${CAELESTIA_DIR:-/etc/xdg/quickshell/caelestia}"

if [[ ! -d "$CAELESTIA_DIR" ]]; then
    echo "error: Caelestia shell not found at $CAELESTIA_DIR" >&2
    echo "set CAELESTIA_DIR to its location and retry" >&2
    exit 1
fi

for d in components services utils modules assets; do
    ln -sfn "$CAELESTIA_DIR/$d" "$d"
    echo "linked $d -> $CAELESTIA_DIR/$d"
done

echo "done"
