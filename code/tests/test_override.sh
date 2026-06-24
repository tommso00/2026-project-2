#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

OUT_DIR="runtime/test_outputs"
mkdir -p "$OUT_DIR"

TEST_NAME="test_override"
OUT_FILE="$OUT_DIR/${TEST_NAME}.controller.out"
MANUAL_OUT="$OUT_DIR/${TEST_NAME}.manual.out"
CTRL_IN="$OUT_DIR/${TEST_NAME}.fifo"

fail() {
    echo "[FAIL] $1"
    if [ -f "$OUT_FILE" ]; then
        echo "----- controller output -----"
        cat "$OUT_FILE"
        echo "-----------------------------"
    fi
    if [ -f "$MANUAL_OUT" ]; then
        echo "----- manual client output -----"
        cat "$MANUAL_OUT"
        echo "--------------------------------"
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

send_cmd() {
    echo "$1" >&"$WRITER_FD" || fail "failed to send command: $1"
}

wait_for_pattern() {
    local p="$1" t="$2" w=0
    while [ "$w" -lt "$t" ]; do
        if grep -Eq "$p" "$OUT_FILE"; then
            return 0
        fi
        sleep 1
        w=$((w+1))
    done
    grep -Eq "$p" "$OUT_FILE"
}

bash scripts/cleanup_ipc.sh >/dev/null 2>&1 || true
rm -f "$CTRL_IN"
: > "$OUT_FILE"
: > "$MANUAL_OUT"

mkfifo "$CTRL_IN" || fail "failed to create controller fifo"
./bin/domotics_controller < "$CTRL_IN" > "$OUT_FILE" 2>&1 &
CTRL_PID=$!
exec {WRITER_FD}> "$CTRL_IN" || fail "failed to open controller input fifo"

send_cmd "add hub"
wait_for_pattern "Added device: id=1 type=hub" 5 || fail "hub not added as expected"

send_cmd "add bulb"
wait_for_pattern "Added device: id=2 type=bulb" 5 || fail "first bulb not added as expected"

send_cmd "add bulb"
wait_for_pattern "Added device: id=3 type=bulb" 5 || fail "second bulb not added as expected"

send_cmd "link 2 to 1"
wait_for_pattern "Linked device 2 to 1" 10 || fail "link 2 -> 1 not reported"
sleep 1

send_cmd "link 3 to 1"
wait_for_pattern "Linked device 3 to 1" 10 || fail "link 3 -> 1 not reported"
sleep 1

# 1) Porta il sistema in stato coerente ON
send_cmd "switch 1 power on"
wait_for_pattern "hub 1 switched on" 15 || fail "hub switch on not confirmed"

sleep 2
send_cmd "info 1"
sleep 2
send_cmd "info 2"
sleep 2
send_cmd "info 3"

wait_for_pattern "hub id=1" 15 || fail "missing hub 1 detail before manual override"
wait_for_pattern "bulb id=2 parent=1 state=on manual_override=false" 15 || fail "bulb 2 not ON before manual override"
wait_for_pattern "bulb id=3 parent=1 state=on manual_override=false" 15 || fail "bulb 3 not ON before manual override"

# 2) Override manuale DOPO stato coerente raggiunto
./bin/manual_client 2 switch power off > "$MANUAL_OUT" 2>&1 || fail "manual override command failed"
grep -q "Manual command sent successfully to device 2" "$MANUAL_OUT" || fail "manual client did not confirm command"

sleep 3
send_cmd "info 1"
sleep 2
send_cmd "info 2"
sleep 2
send_cmd "info 3"

wait_for_pattern "bulb id=2 parent=1 state=off manual_override=true" 20 || fail "bulb 2 did not report manual override OFF state"
wait_for_pattern "bulb id=3 parent=1 state=on manual_override=false" 20 || fail "bulb 3 did not stay ON and coherent after sibling override"
wait_for_pattern "hub id=1 .*manual_override|hub id=1 .*inconsistent|hub id=1 .*child_unreachable|hub id=1 .*error=" 20 || fail "hub 1 did not expose any override/inconsistent/error state after child manual override"

# 3) Nuovo comando del controller: deve riconciliare tutto
send_cmd "switch 1 power on"
wait_for_pattern "hub 1 switched on" 15 || fail "hub reconciliation switch not confirmed"

sleep 3
send_cmd "info 1"
sleep 2
send_cmd "info 2"
sleep 2
send_cmd "info 3"

wait_for_pattern "hub id=1" 20 || fail "missing hub 1 detail after reconciliation"
wait_for_pattern "bulb id=2 parent=1 state=on manual_override=false" 20 || fail "bulb 2 did not return to ON with manual_override=false after controller reconciliation"
wait_for_pattern "bulb id=3 parent=1 state=on manual_override=false" 20 || fail "bulb 3 did not remain coherent during override recovery"

send_cmd "exit"
exec {WRITER_FD}>&-
wait "$CTRL_PID" 2>/dev/null || true
unset CTRL_PID

MATCH_BULB2_OFF="$(grep -c "bulb id=2 parent=1 state=off manual_override=true" "$OUT_FILE" || true)"
if [ "$MATCH_BULB2_OFF" -lt 1 ]; then
    fail "bulb 2 did not show manual override OFF state"
fi

MATCH_BULB2_ON="$(grep -c "bulb id=2 parent=1 state=on manual_override=false" "$OUT_FILE" || true)"
if [ "$MATCH_BULB2_ON" -lt 1 ]; then
    fail "bulb 2 did not recover to ON with manual_override=false"
fi

MATCH_BULB3_ON="$(grep -c "bulb id=3 parent=1 state=on manual_override=false" "$OUT_FILE" || true)"
if [ "$MATCH_BULB3_ON" -lt 1 ]; then
    fail "bulb 3 did not remain coherent during override scenario"
fi

pass