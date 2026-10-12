#!/bin/bash
# Build every example for the web and stage each app.wasm into the showcase site.
#
# Usage:
#   ./tools/build_web_all.sh [release] [--out site] [only <name>...]
#
# Examples:
#   ./tools/build_web_all.sh release              # release builds for all examples
#   ./tools/build_web_all.sh release only triangle cube
#
# Requires: odin on PATH, and staged site files (node site/tools/prep_examples.mjs).
# Each example is built with the existing examples/build.sh ("web" target),
# then build/app.wasm is moved to <out>/public/e/<name>/app.wasm.

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODE=""
OUT="site"
ONLY=()

for arg in "$@"; do
    case "$arg" in
        release) MODE="release" ;;
        --out) OUT_NEXT=1 ;;
        only) ONLY_NEXT=1 ;;
        *)
            if [ "${OUT_NEXT:-0}" = 1 ]; then OUT="$arg"; OUT_NEXT=0;
            elif [ "${ONLY_NEXT:-0}" = 1 ]; then ONLY+=("$arg");
            else ONLY+=("$arg"); fi
            ;;
    esac
done

if [ ${#ONLY[@]} -eq 0 ]; then
    mapfile -t NAMES < <(node "$ROOT/site/tools/prep_examples.mjs" --list)
else
    NAMES=("${ONLY[@]}")
fi

SITE="$ROOT/$OUT"
FAILED=()
BUILT=0

for name in "${NAMES[@]}"; do
    echo "[SITE] --- Building '$name' for web..."
    # Via bash: examples/build.sh is not committed executable.
    if [ -n "$MODE" ]; then
        (cd "$ROOT/examples" && bash build.sh "$name" web "$MODE") || { FAILED+=("$name"); continue; }
    else
        (cd "$ROOT/examples" && bash build.sh "$name" web) || { FAILED+=("$name"); continue; }
    fi
    wasm="$ROOT/examples/build/app.wasm"
    dest="$SITE/public/e/$name"
    if [ ! -f "$wasm" ]; then
        echo "[SITE] --- Missing $wasm after building '$name'"
        FAILED+=("$name")
        continue
    fi
    mkdir -p "$dest"
    mv "$wasm" "$dest/app.wasm"
    BUILT=$((BUILT + 1))
    echo "[SITE] --- Staged public/e/$name/app.wasm"
done

echo "[SITE] --- Done: $BUILT built, ${#FAILED[@]} failed."
if [ ${#FAILED[@]} -ne 0 ]; then
    echo "[SITE] --- Failed: ${FAILED[*]}"
    exit 1
fi
