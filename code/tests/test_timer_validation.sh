#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

OUT_DIR="runtime/test_outputs"
mkdir -p "$OUT_DIR"

TEST_NAME="test_timer_validation"
CTRL_OUT="$OUT_DIR/${TEST_NAME}.controller.out"
CTRL_IN="$OUT_DIR/${TEST_NAME}.fifo"
MANUAL_OUT="$OUT_DIR/${TEST_NAME}.manual.out"

fail() {
    echo "[FAIL] $1"
    if [ -f "$CTRL_OUT" ]; then
        echo "----- controller output -----"
        cat "$CTRL_OUT"
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
    local f="$1" p="$2" t="$3" w=0
    while [ "$w" -lt "$t" ]; do
        if grep -Eq "$p" "$f"; then
            return 0
        fi
        sleep 1
        w=$((w+1))
    done
    grep -Eq "$p" "$f"
}

bash scripts/cleanup_ipc.sh >/dev/null 2>&1 || true
rm -f "$CTRL_IN"
: > "$CTRL_OUT"
: > "$MANUAL_OUT"

mkfifo "$CTRL_IN" || fail "failed to create controller fifo"
./bin/domotics_controller < "$CTRL_IN" > "$CTRL_OUT" 2>&1 &
CTRL_PID=$!
exec {WRITER_FD}> "$CTRL_IN" || fail "failed to open controller input fifo"

send_cmd "add timer"
wait_for_pattern "$CTRL_OUT" "Added device: id=1 type=timer" 5 || fail "timer not added as expected"

send_cmd "info 1"
wait_for_pattern "$CTRL_OUT" "timer id=1" 10 || fail "info 1 did not produce timer detail at baseline"

./bin/manual_client 1 set begin 99:99 > "$MANUAL_OUT" 2>&1 || true
grep -q "Manual command sent successfully to device 1" "$MANUAL_OUT" || fail "manual set begin 99:99 did not reach timer"

sleep 2
send_cmd "info 1"
wait_for_pattern "$CTRL_OUT" "timer id=1|error=child_unreachable" 10 || fail "timer did not respond after invalid begin input"
! grep -q "begin=99:99" "$CTRL_OUT" || fail "timer accepted invalid time format 99:99"

./bin/manual_client 1 set begin 10:00 >> "$MANUAL_OUT" 2>&1 || true
./bin/manual_client 1 set end 10:00 >> "$MANUAL_OUT" 2>&1 || true

sleep 2
send_cmd "info 1"
wait_for_pattern "$CTRL_OUT" "timer id=1|error=child_unreachable" 10 || fail "timer did not respond after equal schedule input"
! grep -q "begin=10:00 end=10:00" "$CTRL_OUT" || fail "timer accepted invalid equal schedule begin == end"

send_cmd "exit"
exec {WRITER_FD}>&-
wait "$CTRL_PID" 2>/dev/null || true
unset CTRL_PID

pass