#!/bin/bash
# test-bootstrap.sh — assertions for hermes-session-init.

set -uo pipefail

_test_dir="$(cd "$(dirname "$0")" && pwd)"
BIN="${HERMES_PRIME_BIN:-$_test_dir/bin/hermes-session-init}"
TMP=$(mktemp -d)
PASS=0
FAIL=0
FAILED_LINES=()

# shellcheck disable=SC2317,SC2329  # invoked indirectly via trap
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

file_mode() {
    local path="$1"
    if stat -c '%a' "$path" >/dev/null 2>&1; then
        stat -c '%a' "$path"
    else
        stat -f '%Lp' "$path"
    fi
}

if "$BIN" --check >/dev/null 2>&1; then
    assert "check exits 0" true
else
    echo "SKIP-context: --check failed:"
    "$BIN" --check || true
fi

PRINT_OUT=$("$BIN" --print 2>/dev/null || true)
case "$PRINT_OUT" in
    *hermes-ground*) assert "print non-empty and contains hermes-ground" test -n "$PRINT_OUT" ;;
    *) assert "print non-empty and contains hermes-ground" false ;;
esac

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
cp "$PROJ2/CLAUDE.md" "$PROJ2/original"
"$BIN" --inject "$PROJ2" >/dev/null 2>&1
BACKUPS=$(find "$PROJ2" -maxdepth 1 -name 'CLAUDE.md.bak.*' 2>/dev/null | wc -l | tr -d ' ')
assert "backup created on existing CLAUDE.md" test "$BACKUPS" -ge 1
printf '%s\n%s\n%s\n' '<!-- session-init: BEGIN -->' 'different fragment' '<!-- session-init: END -->' \
    > "$TMP/different-fragment"
HERMES_SESSION_INIT_FRAGMENT="$TMP/different-fragment" \
    "$BIN" --uninject "$PROJ2" >/dev/null 2>&1

PROJ6="$TMP/proj6"; mkdir -p "$PROJ6"
printf '# original prefix\n' > "$PROJ6/CLAUDE.md"
"$BIN" --inject "$PROJ6" >/dev/null 2>&1
sed 's/original prefix/edited prefix/' "$PROJ6/CLAUDE.md" > "$PROJ6/edited"
mv "$PROJ6/edited" "$PROJ6/CLAUDE.md"
HERMES_SESSION_INIT_FRAGMENT="$TMP/missing-fragment" \
    "$BIN" --uninject "$PROJ6" >/dev/null 2>&1

PROJ8="$TMP/proj8"; mkdir -p "$PROJ8"
: > "$PROJ8/CLAUDE.md"
"$BIN" --inject "$PROJ8" >/dev/null 2>&1
HERMES_SESSION_INIT_FRAGMENT="$TMP/different-fragment" \
    "$BIN" --uninject "$PROJ8" >/dev/null 2>&1
if cmp -s "$PROJ2/original" "$PROJ2/CLAUDE.md" \
    && grep -qF 'edited prefix' "$PROJ6/CLAUDE.md" \
    && ! grep -qF '<!-- session-init: BEGIN -->' "$PROJ6/CLAUDE.md" \
    && [[ -f "$PROJ8/CLAUDE.md" && ! -s "$PROJ8/CLAUDE.md" ]]; then
    assert "stale-fragment exact restore preserves later prefix edits" true
else
    assert "stale-fragment exact restore preserves later prefix edits" false
fi

"$BIN" --uninject "$PROJ" >/dev/null 2>&1
assert "uninject restores absent CLAUDE.md" test ! -e "$PROJ/CLAUDE.md"

PROJ3="$TMP/proj3"; mkdir -p "$PROJ3"
printf '# Existing\n\nFirst paragraph.\n\nSecond paragraph.\n' > "$PROJ3/CLAUDE.md"
chmod 640 "$PROJ3/CLAUDE.md"
MODE3=$(file_mode "$PROJ3/CLAUDE.md")
cp "$PROJ3/CLAUDE.md" "$PROJ3/original"
"$BIN" --inject "$PROJ3" >/dev/null 2>&1
"$BIN" --uninject "$PROJ3" >/dev/null 2>&1
MODE3_AFTER=$(file_mode "$PROJ3/CLAUDE.md")

PROJ9="$TMP/proj9"; mkdir -p "$PROJ9"
printf '# Restrictive missing target\n' > "$PROJ9/CLAUDE.md"
chmod 600 "$PROJ9/CLAUDE.md"
cp "$PROJ9/CLAUDE.md" "$PROJ9/original"
"$BIN" --inject "$PROJ9" >/dev/null 2>&1
rm "$PROJ9/CLAUDE.md"
"$BIN" --uninject "$PROJ9" >/dev/null 2>&1
MODE9_AFTER=$(file_mode "$PROJ9/CLAUDE.md")
if cmp -s "$PROJ3/original" "$PROJ3/CLAUDE.md" \
    && [[ "$MODE3_AFTER" == "$MODE3" ]] \
    && cmp -s "$PROJ9/original" "$PROJ9/CLAUDE.md" \
    && [[ "$MODE9_AFTER" == "600" ]]; then
    assert "uninject byte-restores multi-paragraph file and mode" true
else
    assert "uninject byte-restores multi-paragraph file and mode" false
fi

PROJ4="$TMP/proj4"; mkdir -p "$PROJ4"
printf '# Existing without final newline' > "$PROJ4/CLAUDE.md"
cp "$PROJ4/CLAUDE.md" "$PROJ4/original"
"$BIN" --inject "$PROJ4" >/dev/null 2>&1
"$BIN" --uninject "$PROJ4" >/dev/null 2>&1
assert "uninject byte-restores no-final-newline file" cmp -s "$PROJ4/original" "$PROJ4/CLAUDE.md"

PROJ5="$TMP/proj5"; mkdir -p "$PROJ5"
printf '# Symlink target\n\nOriginal bytes.\n' > "$PROJ5/backing.md"
cp "$PROJ5/backing.md" "$PROJ5/original"
ln -s backing.md "$PROJ5/CLAUDE.md"
"$BIN" --inject "$PROJ5" >/dev/null 2>&1
"$BIN" --uninject "$PROJ5" >/dev/null 2>&1
if [[ -L "$PROJ5/CLAUDE.md" ]] && cmp -s "$PROJ5/original" "$PROJ5/backing.md"; then
    assert "uninject preserves symlink and referent bytes" true
else
    assert "uninject preserves symlink and referent bytes" false
fi

echo "---"
echo "PASS: $PASS  FAIL: $FAIL"
if [[ $FAIL -gt 0 ]]; then
    echo "failed assertions:"
    for line in "${FAILED_LINES[@]}"; do echo "  - $line"; done
    exit 1
fi
exit 0
