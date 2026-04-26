#!/bin/bash
# scripts/local-ci.sh — mirror of .github/workflows/ci.yml that runs locally.
#
# Purpose: catch CI-fatal issues BEFORE pushing. Run this before every push
# to hermes-prime. Exit non-zero on any failure that CI would also fail on.
#
# Usage:
#   ./scripts/local-ci.sh
#
# Exit codes:
#   0 — all checks pass; safe to push
#   1 — at least one check failed; CI would fail. Do not push.

set -uo pipefail

cd "$(dirname "$0")/.."

RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RESET=$'\033[0m'

FAIL=0

run_check() {
    local name="$1"; shift
    echo ""
    echo "=== $name ==="
    if "$@"; then
        echo "${GREEN}PASS${RESET}: $name"
    else
        echo "${RED}FAIL${RESET}: $name"
        FAIL=$((FAIL+1))
    fi
}

# 1. shellcheck
if command -v shellcheck >/dev/null 2>&1; then
    run_check "shellcheck (bash binary + tests + evals)" \
        shellcheck bin/hermes-session-init test-bootstrap.sh evals/preliminary-bootstrap-eval.sh
else
    echo "${YELLOW}WARN${RESET}: shellcheck not installed. CI will run it; install with 'brew install shellcheck'."
    FAIL=$((FAIL+1))
fi

# 2. bash test suite
run_check "bash test-bootstrap.sh (9 assertions)" bash test-bootstrap.sh

# 3. MCP server tests (Python)
if [[ -d mcp-server ]]; then
    if command -v python >/dev/null 2>&1; then
        run_check "mcp-server pytest (10 tests)" bash -c "cd mcp-server && python -m pytest -q"
    else
        echo "${YELLOW}WARN${RESET}: python not found; skipping mcp-server tests"
    fi
fi

# 4. fragment size budget (rubric ships with 8000-char window)
SIZE=$(wc -c < CLAUDE-fragment.md)
if [[ $SIZE -le 8000 ]]; then
    echo ""
    echo "=== fragment size ==="
    echo "${GREEN}PASS${RESET}: CLAUDE-fragment.md is $SIZE chars (≤8000)"
else
    echo ""
    echo "=== fragment size ==="
    echo "${RED}FAIL${RESET}: CLAUDE-fragment.md is $SIZE chars (>8000 char window)"
    FAIL=$((FAIL+1))
fi

# 5. fragment markers present (uninject would break without these)
if grep -qF '<!-- session-init: BEGIN -->' CLAUDE-fragment.md \
   && grep -qF '<!-- session-init: END -->' CLAUDE-fragment.md; then
    echo "${GREEN}PASS${RESET}: fragment marker pair present"
else
    echo "${RED}FAIL${RESET}: fragment missing BEGIN/END markers"
    FAIL=$((FAIL+1))
fi

echo ""
echo "==================================="
if [[ $FAIL -eq 0 ]]; then
    echo "${GREEN}ALL CHECKS PASSED${RESET} — safe to push."
    exit 0
else
    echo "${RED}FAILED: $FAIL check(s) — DO NOT PUSH${RESET}"
    echo "Fix the failures above; CI will reject this commit otherwise."
    exit 1
fi
