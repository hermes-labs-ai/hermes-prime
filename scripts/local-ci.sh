#!/bin/bash
# scripts/local-ci.sh — local mechanism gate (hosted checks plus local invariants).
#
# Purpose: run named mechanism checks before requesting any public action.
# Passing is not push/release authorization or a complete release verdict.
#
# Usage:
#   ./scripts/local-ci.sh
#
# Exit codes:
#   0 — all named local checks pass; public actions remain separately gated
#   1 — at least one required check failed

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

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
        shellcheck bin/hermes-session-init test-bootstrap.sh evals/preliminary-bootstrap-eval.sh scripts/check-public-truth.sh
else
    echo "${YELLOW}WARN${RESET}: shellcheck not installed. CI will run it; install with 'brew install shellcheck'."
    FAIL=$((FAIL+1))
fi

# 2. bash test suite
run_check "bash test-bootstrap.sh (11 assertions)" bash test-bootstrap.sh

# 3. MCP server tests (Python)
if [[ -d mcp-server ]]; then
    if command -v pytest >/dev/null 2>&1; then
        run_check "mcp-server pytest (12 tests)" env \
            PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 PYTHONDONTWRITEBYTECODE=1 \
            pytest -q -p no:cacheprovider mcp-server/test_hermes_prime_mcp.py
    elif command -v python3 >/dev/null 2>&1 \
        && python3 -c 'import pytest' >/dev/null 2>&1; then
        run_check "mcp-server pytest (12 tests)" env \
            PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 PYTHONDONTWRITEBYTECODE=1 \
            python3 -m pytest -q -p no:cacheprovider mcp-server/test_hermes_prime_mcp.py
    else
        echo "${YELLOW}WARN${RESET}: pytest not available"
        FAIL=$((FAIL+1))
    fi
fi

# 4. current public-truth surface
run_check "current public-truth surfaces" bash scripts/check-public-truth.sh

# 5. fragment size budget (rubric ships with 8000-char window)
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

# 6. fragment markers present (uninject would break without these)
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
    echo "${GREEN}ALL NAMED LOCAL CHECKS PASSED${RESET} — public actions remain separately gated."
    exit 0
else
    echo "${RED}FAILED: $FAIL check(s) — DO NOT PUSH${RESET}"
    echo "Fix the failures above before requesting release authorization."
    exit 1
fi
