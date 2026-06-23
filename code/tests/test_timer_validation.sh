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

send_cmd() { echo "$1" >&"$WRITER_FD" || fail "failed to send command: $1"; }
wait_for_pattern() { local f="$1" p="$2" t="$3" w=0; while [ "$w" -lt "$t" ]; do grep -Eq "$p" "$f" && return 0; sleep 1; w=$((w+1)); done; return 1; }

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
send_cmd "add bulb"
wait_for_pattern "$CTRL_OUT" "Added device: id=2 type=bulb" 5 || fail "bulb not added as expected"
send_cmd "link 2 to 1"
wait_for_pattern "$CTRL_OUT" "Linked device 2 to 1" 5 || fail "link 2 -> 1 not reported"
grep -q "^2[[:space:]]+bulb[[:space:]]" "$CTRL_OUT" || fail "link 2 -> 1 not reflected in list output"

./bin/manual_client 1 set begin 99:99 > "$MANUAL_OUT" 2>&1 || true
grep -q "Manual command sent successfully to device 1" "$MANUAL_OUT" || fail "manual set begin 99:99 did not reach timer"
send_cmd "info 1"
wait_for_pattern "$CTRL_OUT" "timer id=1" 6 || fail "info 1 did not produce timer detail after invalid begin"
! grep -q "begin=99:99" "$CTRL_OUT" || fail "timer accepted invalid time format 99:99"

./bin/manual_client 1 set begin 10:00 >> "$MANUAL_OUT" 2>&1 || true
./bin/manual_client 1 set end 10:00 >> "$MANUAL_OUT" 2>&1 || true
send_cmd "info 1"
wait_for_pattern "$CTRL_OUT" "timer id=1" 6 || fail "info 1 did not produce timer detail after begin == end"
! grep -q "begin=10:00 end=10:00" "$CTRL_OUT" || fail "timer accepted invalid equal schedule begin == end"

<<<<<<< HEAD
./bin/manual_client 1 set begin 23:00 >> "$MANUAL_OUT" 2>&1 || true
./bin/manual_client 1 set end 08:00 >> "$MANUAL_OUT" 2>&1 || true
=======
./bin/manual_client 1 set begin 08:00 >> "$MANUAL_OUT" 2>&1 || true
./bin/manual_client 1 set end 23:00 >> "$MANUAL_OUT" 2>&1 || true

sleep 3
>>>>>>> 66b2deeaa8880a9ff3e94e2549f62edcdb7e26dc
send_cmd "info 1"
wait_for_pattern "$CTRL_OUT" "timer id=1 state=.*begin=23:00 end=08:00" 6 || fail "timer did not accept overnight schedule 23:00 -> 08:00"
grep -q "timer id=1 state=off begin=23:00 end=08:00" "$CTRL_OUT" || fail "timer did not expose valid overnight schedule 23:00 -> 08:00"

<<<<<<< HEAD
<<<<<<< HEAD
./bin/manual_client 1 set begin 12:00 >> "$MANUAL_OUT" 2>&1 || true
./bin/manual_client 1 set end 11:00 >> "$MANUAL_OUT" 2>&1 || true
send_cmd "info 1"
wait_for_pattern "$CTRL_OUT" "timer id=1" 6 || fail "info 1 did not produce timer detail after end before begin"
! grep -q "begin=12:00 end=11:00" "$CTRL_OUT" || fail "timer accepted invalid schedule with end before begin"
=======
grep -E -q "timer id=1 parent=0 state=(on|off) begin=23:00 end=08:00" "$CTRL_OUT" || \
    fail "timer did not accept overnight schedule 23:00 -> 08:00"
>>>>>>> ee0d8e0038ada224cf5bb95bd2b18f256d4aa693
=======
grep -E -q "timer id=1 parent=0 state=(on|off) begin=08:00 end=23:00" "$CTRL_OUT" || \
    fail "timer did not accept schedule 08:00 -> 23:00"
>>>>>>> 66b2deeaa8880a9ff3e94e2549f62edcdb7e26dc

send_cmd "exit"
exec {WRITER_FD}>&-
wait "$CTRL_PID" 2>/dev/null || true
unset CTRL_PID

pass