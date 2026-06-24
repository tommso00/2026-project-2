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

assert_contains() {
    local pattern="$1"
    local message="$2"
    grep -E -q "$pattern" "$OUT_FILE" || fail "$message"
}

assert_not_contains() {
    local pattern="$1"
    local message="$2"
    if grep -E -q "$pattern" "$OUT_FILE"; then
        fail "$message"
    fi
}

bash scripts/cleanup_ipc.sh >/dev/null 2>&1 || true

CTRL_IN="$OUT_DIR/${TEST_NAME}.fifo"
rm -f "$CTRL_IN"
mkfifo "$CTRL_IN" || fail "failed to create controller fifo"

CONTROLLER_STATUS=0
./bin/domotics_controller < "$CTRL_IN" > "$OUT_FILE" 2>&1 &
CTRL_PID=$!

exec {WRITER_FD}> "$CTRL_IN" || fail "failed to open controller input fifo"


echo "add hub" >&"$WRITER_FD"; sleep 1
echo "add bulb" >&"$WRITER_FD"; sleep 1
echo "add window" >&"$WRITER_FD"; sleep 1
echo "add hub" >&"$WRITER_FD"; sleep 1
echo "list" >&"$WRITER_FD"; sleep 1

echo "link 2 to 1" >&"$WRITER_FD"; sleep 2
echo "list" >&"$WRITER_FD"; sleep 1
echo "info 2" >&"$WRITER_FD"; sleep 6

echo "link 3 to 2" >&"$WRITER_FD"; sleep 2
echo "list" >&"$WRITER_FD"; sleep 1
echo "info 3" >&"$WRITER_FD"; sleep 6

echo "link 4 to 3" >&"$WRITER_FD"; sleep 2
echo "list" >&"$WRITER_FD"; sleep 1
echo "info 4" >&"$WRITER_FD"; sleep 6

echo "link 2 to 4" >&"$WRITER_FD"; sleep 3
echo "list" >&"$WRITER_FD"; sleep 1
echo "info 2" >&"$WRITER_FD"; sleep 8

echo "exit" >&"$WRITER_FD"

exec {WRITER_FD}>&-
wait "$CTRL_PID" 2>/dev/null || true

[ "$CONTROLLER_STATUS" -eq 0 ] || fail "controller exited with non-zero status: $CONTROLLER_STATUS"

assert_contains "Added device: id=1 type=hub" "hub 1 not added as expected"
assert_contains "Added device: id=2 type=bulb" "bulb 2 not added as expected"
assert_contains "Added device: id=3 type=window" "window 3 not added as expected"
assert_contains "Added device: id=4 type=hub" "hub 4 not added as expected"

assert_contains "Linked device 2 to 1" "valid link 2 -> 1 not reported"
assert_contains "^2[[:space:]]+bulb[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+1$" \
    "device 2 parent was not updated to 1 after valid link"


assert_contains "bulb id=2 .*parent=1|bulb id=2 .* parent 1|bulb id=2 .*parent: 1" \
    "device 2 detail does not show parent 1 after valid link"

assert_not_contains "Linked device 3 to 2" "invalid link 3 -> 2 unexpectedly succeeded"
assert_contains "Error: The selected devices are not compatible\." \
    "missing incompatible-devices error for link 3 -> 2"
assert_contains "^3[[:space:]]+window[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+0$" \
    "device 3 parent changed unexpectedly after invalid link 3 -> 2"

# Anche info 3 non deve mostrare un parent cambiato
assert_not_contains "window id=3 .*parent=2|window id=3 .* parent 2|window id=3 .*parent: 2" \
    "device 3 detail unexpectedly shows parent 2 after failed link"

assert_not_contains "Linked device 4 to 3" "invalid link 4 -> 3 unexpectedly succeeded"
assert_contains "Error: The selected devices are not compatible\." \
    "missing incompatible-devices error for link 4 -> 3"
assert_contains "^4[[:space:]]+hub[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+0$" \
    "device 4 parent changed unexpectedly after invalid link 4 -> 3"

assert_not_contains "hub id=4 .*parent=3|hub id=4 .* parent 3|hub id=4 .*parent: 3" \
    "device 4 detail unexpectedly shows parent 3 after failed link"

assert_contains "Linked device 2 to 4" "re-link 2 -> 4 was not accepted as expected by this implementation"
assert_contains "^2[[:space:]]+bulb[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+4$" \
    "device 2 parent was not updated to 4 after re-link"

assert_contains "bulb id=2 .*parent=4|bulb id=2 .* parent 4|bulb id=2 .*parent: 4" \
    "device 2 detail does not show parent 4 after re-link"

assert_not_contains "Command not valid\." "unexpected invalid command found in controller output"
assert_not_contains "Parse error\." "unexpected parse error found in controller output"

pass