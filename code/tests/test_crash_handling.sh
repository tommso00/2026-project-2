#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

OUT_DIR="runtime/test_outputs"
mkdir -p "$OUT_DIR"

TEST_NAME="test_crash_handling"
CTRL_OUT="$OUT_DIR/${TEST_NAME}.controller.out"
CTRL_IN="$OUT_DIR/${TEST_NAME}.fifo"

fail() {
    echo "[FAIL] $1"
    if [ -f "$CTRL_OUT" ]; then
        echo "----- controller output -----"
        cat "$CTRL_OUT"
        echo "-----------------------------"
    fi
    [ -n "${WRITER_FD:-}" ] && exec {WRITER_FD}>&- 2>/dev/null || true
    [ -n "${CTRL_PID:-}" ] && wait "$CTRL_PID" 2>/dev/null || true
    rm -f "$CTRL_IN"
    bash scripts/cleanup_ipc.sh >/dev/null 2>&1 || true
    exit 1
}

pass() {
    echo "[PASS] $TEST_NAME"
    [ -n "${WRITER_FD:-}" ] && exec {WRITER_FD}>&- 2>/dev/null || true
    [ -n "${CTRL_PID:-}" ] && wait "$CTRL_PID" 2>/dev/null || true
    rm -f "$CTRL_IN"
    bash scripts/cleanup_ipc.sh >/dev/null 2>&1 || true
    exit 0
}

send_cmd() { echo "$1" >&"$WRITER_FD" || fail "failed to send command: $1"; }
wait_for_pattern() { local p="$1" t="$2" w=0; while [ "$w" -lt "$t" ]; do grep -Eq "$p" "$CTRL_OUT" && return 0; sleep 1; w=$((w+1)); done; return 1; }

bash scripts/cleanup_ipc.sh >/dev/null 2>&1 || true
rm -f "$CTRL_IN"
: > "$CTRL_OUT"

mkfifo "$CTRL_IN" || fail "failed to create controller fifo"
./bin/domotics_controller < "$CTRL_IN" > "$CTRL_OUT" 2>&1 &
CTRL_PID=$!
exec {WRITER_FD}> "$CTRL_IN" || fail "failed to open controller input fifo"

send_cmd "add hub"
wait_for_pattern "Added device: id=1 type=hub" 5 || fail "hub not added as expected"
send_cmd "add bulb"
wait_for_pattern "Added device: id=2 type=bulb" 5 || fail "bulb not added as expected"
send_cmd "link 2 to 1"
wait_for_pattern "Linked device 2 to 1" 5 || fail "link 2 -> 1 not reported"
send_cmd "list"
wait_for_pattern "^2[[:space:]]+bulb[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+1$" 5 || fail "could not confirm bulb pid from list output"

BULB_PID=$(grep -Eo '^2[[:space:]]+bulb[[:space:]]+[0-9]+' "$CTRL_OUT" | tail -n1 | awk '{print $3}')
[ -n "$BULB_PID" ] || fail "could not extract bulb pid from list output"
kill -9 "$BULB_PID" 2>/dev/null || fail "failed to SIGKILL bulb process"

wait_for_pattern "(device 2.*(crash|crashed|unreachable|down)|child.*unreachable|error=.*crash|error=.*unreachable)" 6 || fail "missing specific crash/downtime notification after SIGKILL"

send_cmd "info 1"
wait_for_pattern "hub id=1" 6 || fail "hub info was not produced after child crash"

send_cmd "switch 1 power on"
wait_for_pattern "(hub 1 switched on|hub id=1.*state=on|switch.*1.*on)" 8 || fail "hub did not respond after child crash"

send_cmd "list"
wait_for_pattern "^1[[:space:]]+hub[[:space:]]" 6 || fail "hub disappeared after child crash"

send_cmd "exit"
exec {WRITER_FD}>&-
wait "$CTRL_PID" 2>/dev/null || true
unset CTRL_PID

if ! grep -Eq "(device 2.*(crash|crashed|unreachable|down)|child.*unreachable|error=.*crash|error=.*unreachable)" "$CTRL_OUT"; then
    fail "crash handling did not emit an expected error/notification"
fi
if ! grep -Eq "(hub 1 switched on|hub id=1.*state=on|switch.*1.*on)" "$CTRL_OUT"; then
    fail "hub did not produce a visible response after child crash"
fi
if grep -Eq "^2[[:space:]]+bulb[[:space:]]" "$CTRL_OUT"; then
    fail "crashed child still appears in final device list"
fi
if ! grep -Eq "^1[[:space:]]+hub[[:space:]]" "$CTRL_OUT"; then
    fail "hub disappeared after child crash"
fi

pass