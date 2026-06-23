#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

OUT_DIR="runtime/test_outputs"
mkdir -p "$OUT_DIR"

TEST_NAME="test_linking"
CMD_FILE="$OUT_DIR/${TEST_NAME}.commands"
OUT_FILE="$OUT_DIR/${TEST_NAME}.out"

fail() {
    echo "[FAIL] $1"
    if [ -f "$OUT_FILE" ]; then
        echo "----- controller output -----"
        cat "$OUT_FILE"
        echo "-----------------------------"
    fi
    bash scripts/cleanup_ipc.sh >/dev/null 2>&1 || true
    exit 1
}

pass() {
    echo "[PASS] $TEST_NAME"
    bash scripts/cleanup_ipc.sh >/dev/null 2>&1 || true
    exit 0
}

bash scripts/cleanup_ipc.sh >/dev/null 2>&1 || true

cat > "$CMD_FILE" <<'EOF'
add hub
add bulb
add window
add hub
list
link 2 to 1
list
info 2
link 3 to 2
list
info 3
link 4 to 3
list
info 4
link 2 to 4
list
info 2
EOF

CONTROLLER_STATUS=0

# --- FIX DEFINITIVO: Leggiamo riga per riga e aspettiamo 2 secondi tra un comando e l'altro ---
{
    while IFS= read -r cmd; do
        echo "$cmd"
        sleep 2
    done < "$CMD_FILE"
    sleep 5
    echo "exit"
} | ./bin/domotics_controller > "$OUT_FILE" 2>&1 || CONTROLLER_STATUS=$?

[ "$CONTROLLER_STATUS" -eq 0 ] || fail "controller exited with non-zero status: $CONTROLLER_STATUS"

grep -q "Added device: id=1 type=hub" "$OUT_FILE" || fail "hub 1 not added as expected"
grep -q "Added device: id=2 type=bulb" "$OUT_FILE" || fail "bulb 2 not added as expected"
grep -q "Added device: id=3 type=window" "$OUT_FILE" || fail "window 3 not added as expected"
grep -q "Added device: id=4 type=hub" "$OUT_FILE" || fail "hub 4 not added as expected"

grep -q "Linked device 2 to 1" "$OUT_FILE" || fail "valid link 2 -> 1 not reported"
grep -E -q "^2[[:space:]]+bulb[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+1$" "$OUT_FILE" || fail "device 2 parent was not updated to 1 after valid link"
grep -q "bulb id=2" "$OUT_FILE" || fail "info 2 did not produce bulb detail after valid link"

if grep -q "linked.*parent=1\|parent=1" "$OUT_FILE"; then :; else
    grep -q "bulb id=2 state=off manual_override=false time=0" "$OUT_FILE" || fail "device 2 detail does not show expected info after valid link"
fi

grep -q "Error: The selected devices are not compatible." "$OUT_FILE" || fail "missing incompatible-devices error message"
grep -E -q "^3[[:space:]]+window[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+0$" "$OUT_FILE" || fail "device 3 parent changed unexpectedly after invalid link 3 -> 2"
grep -E -q "^4[[:space:]]+hub[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+0$" "$OUT_FILE" || fail "device 4 parent changed unexpectedly after invalid link 4 -> 3"

grep -q "Linked device 2 to 4" "$OUT_FILE" || fail "re-link 2 -> 4 was not accepted as expected by this implementation"
grep -E -q "^2[[:space:]]+bulb[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+4$" "$OUT_FILE" || fail "device 2 parent was not updated to 4 after re-link"
grep -q "bulb id=2" "$OUT_FILE" || fail "info 2 missing after re-link"

pass