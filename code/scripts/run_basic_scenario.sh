#!/usr/bin/env bash

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

./bin/domotics_controller <<'EOF'
add hub
add bulb
add window
link 2 to 1
link 3 to 1
list
info 1
switch 1 main on
list
EOF