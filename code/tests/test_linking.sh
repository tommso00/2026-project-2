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
list
link 2 to 1
list
link 3 to 2
list
exit
EOF

./bin/domotics_controller < "$CMD_FILE" > "$OUT_FILE" 2>&1 || true

grep -q "Added device: id=1 type=hub" "$OUT_FILE" || fail "hub not added as expected"
grep -q "Added device: id=2 type=bulb" "$OUT_FILE" || fail "bulb not added as expected"
grep -q "Added device: id=3 type=window" "$OUT_FILE" || fail "window not added as expected"

grep -q "Linked device 2 to 1" "$OUT_FILE" || fail "valid link 2 -> 1 not reported"

grep -E -q "^2[[:space:]]+bulb[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+1$" "$OUT_FILE" || \
    fail "device 2 parent was not updated to 1 after valid link"

if grep -q "Linked device 3 to 2" "$OUT_FILE"; then
    fail "invalid link 3 -> 2 unexpectedly succeeded"
fi

grep -q "Error: The selected devices are not compatible." "$OUT_FILE" || \
    fail "missing incompatible-devices error message"

grep -E -q "^1[[:space:]]+hub[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+0$" "$OUT_FILE" || \
    fail "device 1 parent changed unexpectedly"

grep -E -q "^2[[:space:]]+bulb[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+1$" "$OUT_FILE" || \
    fail "device 2 parent changed unexpectedly after invalid operation"

grep -E -q "^3[[:space:]]+window[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+0$" "$OUT_FILE" || \
    fail "device 3 parent changed unexpectedly after invalid operation"

pass