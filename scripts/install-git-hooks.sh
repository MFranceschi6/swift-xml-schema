#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$ROOT_DIR/.githooks"
TARGET_DIR="$ROOT_DIR/.git/hooks"

mkdir -p "$TARGET_DIR"

for hook in "$HOOKS_DIR"/*; do
  name="$(basename "$hook")"
  cp "$hook" "$TARGET_DIR/$name"
  chmod +x "$TARGET_DIR/$name"
done

echo "Installed git hooks from $HOOKS_DIR"
