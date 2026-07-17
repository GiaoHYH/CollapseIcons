#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh"
# Kill previous instance
pkill -x CollapseIcons 2>/dev/null || true
open "$ROOT/build/CollapseIcons.app"
