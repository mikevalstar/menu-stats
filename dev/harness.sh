#!/usr/bin/env bash
# Run the widget and service in a throwaway Quickshell instance with a mock
# bar. Prints QML errors and sampler output, then exits. Does not touch the
# running omarchy-shell, so it is safe while the screen is locked.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
scratch="${TMPDIR:-/tmp}/menu-stats-harness"
mkdir -p "$scratch"
ln -sfn /usr/share/omarchy/shell/Ui "$scratch/Ui"
ln -sfn /usr/share/omarchy/shell/Commons "$scratch/Commons"
cp "$repo/dev/harness.qml" "$scratch/shell.qml"

MENU_STATS_DIR="$repo" timeout 20 qs -p "$scratch/shell.qml" 2>&1 \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | grep -Ev 'qt.qpa.services|Saving logs|Shell ID|Launching config|^\s*$' || true
