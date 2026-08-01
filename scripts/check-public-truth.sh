#!/bin/bash
# Fail closed when current authority surfaces reintroduce known-retired claims,
# private workstation paths, or inconsistent source-version metadata.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SOURCE_VERSION="0.2.1-alpha.1"
AUTHORITY_FILES=(
    README.md
    llms.txt
    CLAUDE-fragment.md
    CITATION.cff
    SECURITY.md
    INTENT.md
    CHANGELOG.md
    evals/EVAL-PROTOCOL.md
    evals/runs/2026-04-25/RESULTS.md
)

fail=0

if grep -Eiq \
    'transfer[- ]entropy|token[- ]efficiency|n[[:space:]]*=[[:space:]]*74|~70%|most of our publish-readiness misses|Stop .*drift|work from drifting in its first 30 minutes|drift-prevention|hermes[- ]seal|cryptographic containment' \
    "${AUTHORITY_FILES[@]}"; then
    echo "FAIL: current authority surface contains a retired or unsupported claim" >&2
    fail=1
fi

if git grep -qE '(/Users/|/home/|/var/folders/)' -- . ':!scripts/check-public-truth.sh'; then
    echo "FAIL: tracked current tree contains a private absolute-path pattern" >&2
    fail=1
fi

if [[ -e .hermes-seal.yaml ]]; then
    echo "FAIL: dormant attestation placeholder remains in the current tree" >&2
    fail=1
fi

for file in README.md SECURITY.md CITATION.cff CHANGELOG.md llms.txt \
    bin/hermes-session-init mcp-server/hermes_prime_mcp.py INTENT.md; do
    if ! grep -qF "$SOURCE_VERSION" "$file"; then
        echo "FAIL: $file does not identify source version $SOURCE_VERSION" >&2
        fail=1
    fi
done

if ! grep -qF 'unreleased' README.md \
    || ! grep -qF 'unreleased' SECURITY.md \
    || ! grep -qF 'unreleased' CITATION.cff \
    || ! grep -qF 'Unreleased' CHANGELOG.md \
    || ! grep -qF 'unreleased' llms.txt; then
    echo "FAIL: source authority surfaces do not state the no-public-release boundary" >&2
    fail=1
fi

if [[ "$fail" -ne 0 ]]; then
    exit 1
fi

echo "PASS: current public-truth and source-version checks"
