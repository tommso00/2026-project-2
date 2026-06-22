#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

OUT_DIR="runtime/test_outputs"
mkdir -p "$OUT_DIR"

TEST_NAME="test_cascade_delete"
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
: > "$OUT_FILE"

cat > "$CMD_FILE" <<'EOF'
add hub
add hub
add bulb
link 2 to 1
link 3 to 2
list
info 1
info 2
info 3
del 1
list
info 1
info 2
info 3
exit
EOF

CONTROLLER_STATUS=0
./bin/domotics_controller < "$CMD_FILE" > "$OUT_FILE" 2>&1 || CONTROLLER_STATUS=$?
[ "$CONTROLLER_STATUS" -eq 0 ] || fail "controller exited with non-zero status: $CONTROLLER_STATUS"

grep -q "Added device: id=1 type=hub" "$OUT_FILE" || fail "root hub not added as expected"
grep -q "Added device: id=2 type=hub" "$OUT_FILE" || fail "child hub not added as expected"
grep -q "Added device: id=3 type=bulb" "$OUT_FILE" || fail "grandchild bulb not added as expected"
grep -q "Linked device 2 to 1" "$OUT_FILE" || fail "link 2 -> 1 not reported"
grep -q "Linked device 3 to 2" "$OUT_FILE" || fail "link 3 -> 2 not reported"
grep -E -q "^2[[:space:]]+hub[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+1$" "$OUT_FILE" || fail "device 2 parent was not updated before deletion"
grep -E -q "^3[[:space:]]+bulb[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+2$" "$OUT_FILE" || fail "device 3 parent was not updated before deletion"
grep -q "Deleted device: id=1" "$OUT_FILE" || fail "root device 1 was not deleted"
grep -q "Deleted device: id=2" "$OUT_FILE" || fail "child device 2 was not deleted during cascade"
grep -q "Deleted device: id=3" "$OUT_FILE" || fail "grandchild device 3 was not deleted during cascade"
grep -q "Error: Device not found. Check the name and try again." "$OUT_FILE" || fail "missing post-delete device-not-found error"

after=$(grep -n "Deleted device: id=1" "$OUT_FILE" | tail -n1 | cut -d: -f1)
[ -n "$after" ] || fail "delete marker not found"
rest=$(tail -n +"$after" "$OUT_FILE")
! echo "$rest" | grep -E -q "^1[[:space:]]+hub[[:space:]]" || fail "hub still appears in output after cascade delete"
! echo "$rest" | grep -E -q "^2[[:space:]]+hub[[:space:]]" || fail "child hub still appears in output after cascade delete"
! echo "$rest" | grep -E -q "^3[[:space:]]+bulb[[:space:]]" || fail "bulb still appears in output after cascade delete"

pass