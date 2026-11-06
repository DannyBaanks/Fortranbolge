#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/fortranbolge"
BIN19="$ROOT/fortranbolge19"
TMP_DIR="$(mktemp -d /tmp/fb_test_XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "=== Fortranbolge Test Suite (Linux) ==="

# 1. Classic Gate
echo "--- Test 1: Classic Gate (48 steps) ---"
"$BIN" "$ROOT/fixture.mal" 100 < /dev/null > "$TMP_DIR/gate.out" 2> "$TMP_DIR/gate.err"
DIFF_OUT="$(diff -u <(printf 'Hello, world.\n') "$TMP_DIR/gate.out" || true)"
if [ -n "$DIFF_OUT" ]; then
    echo "FAIL: Output mismatch in Gate"
    exit 1
fi
grep -q '{"final":{"a":19758,"c":85,"d":63},"halt_reason":"VInstruction","output_len":13,"status":"HALTED","steps":48}' "$TMP_DIR/gate.err"
echo "  PASS"

# 2. Unshackled 3^19
echo "--- Test 2: Unshackled 3^19 ---"
"$BIN19" "$ROOT/fixture19.mal" 10 < /dev/null > "$TMP_DIR/fb19.out" 2> "$TMP_DIR/fb19.err"
grep -q '"final":{"a":1162261466,"c":2,"d":2},"halt_reason":"HaltOpcode","status":"HALTED","steps":3' "$TMP_DIR/fb19.err"
echo "  PASS"

echo "ALL TESTS PASSED"
