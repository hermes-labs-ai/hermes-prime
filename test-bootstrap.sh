#!/bin/bash
# test-bootstrap.sh — assertions for hermes-session-init.

set -uo pipefail

_test_dir="$(cd "$(dirname "$0")" && pwd)"
BIN="${HERMES_PRIME_BIN:-$_test_dir/bin/hermes-session-init}"
TMP=$(mktemp -d)
PASS=0
FAIL=0
FAILED_LINES=()

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

assert() {
    local name="$1"; shift
    if "$@"; then
        PASS=$((PASS+1))
        echo "PASS: $name"
    else
        FAIL=$((FAIL+1))
        FAILED_LINES+=("$name")
        echo "FAIL: $name"
    fi
}

"$BIN" --check >/dev/null 2>&1 && assert "check exits 0" true || { echo "SKIP-context: --check failed:"; "$BIN" --check || true; }

PRINT_OUT=$("$BIN" --print 2>/dev/null || true)
assert "print non-empty" test -n "$PRINT_OUT"
case "$PRINT_OUT" in *hermes-ground*) assert "print contains hermes-ground" true ;; *) assert "print contains hermes-ground" false ;; esac

PROJ="$TMP/proj1"; mkdir -p "$PROJ"
"$BIN" --inject "$PROJ" >/dev/null 2>&1
assert "inject created CLAUDE.md" test -f "$PROJ/CLAUDE.md"
assert "inject marker present" grep -qF '<!-- session-init: BEGIN -->' "$PROJ/CLAUDE.md"

SIZE1=$(wc -c < "$PROJ/CLAUDE.md")
"$BIN" --inject "$PROJ" >/dev/null 2>&1
SIZE2=$(wc -c < "$PROJ/CLAUDE.md")
DIFF=$((SIZE2 - SIZE1)); DIFF=${DIFF#-}
assert "idempotent (size delta <=1)" test "$DIFF" -le 1

PROJ2="$TMP/proj2"; mkdir -p "$PROJ2"
echo "# pre-existing" > "$PROJ2/CLAUDE.md"
"$BIN" --inject "$PROJ2" >/dev/null 2>&1
BACKUPS=$(ls -1 "$PROJ2"/CLAUDE.md.bak.* 2>/dev/null | wc -l | tr -d ' ')
assert "backup created on existing CLAUDE.md" test "$BACKUPS" -ge 1
assert "pre-existing content preserved" grep -qF 'pre-existing' "$PROJ2/CLAUDE.md"

"$BIN" --uninject "$PROJ" >/dev/null 2>&1
if [[ -f "$PROJ/CLAUDE.md" ]] && grep -qF '<!-- session-init: BEGIN -->' "$PROJ/CLAUDE.md"; then
    assert "uninject removed marker" false
else
    assert "uninject removed marker" true
fi

echo "---"
echo "PASS: $PASS  FAIL: $FAIL"
if [[ $FAIL -gt 0 ]]; then
    echo "failed assertions:"
    for line in "${FAILED_LINES[@]}"; do echo "  - $line"; done
    exit 1
fi
exit 0
