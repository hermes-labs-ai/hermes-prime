# INTENT — hermes-prime

One-page invariants doc, in the Hermes Labs convention. Read before changing scope.

## What hermes-prime is

A bash bootstrap (~120 LOC) plus a versioned markdown fragment that injects Hermes Labs session conventions into a target project's `CLAUDE.md`. Per-project, marker-anchored, idempotent, fully reversible.

## Accepts

- Per-project injection of a marker-bracketed block into `<project>/CLAUDE.md`.
- Idempotent re-injection (re-running `--inject` is a no-op).
- Existing `CLAUDE.md` content preservation (appended-to, never overwritten; backed up to `CLAUDE.md.bak.<timestamp>`).
- Marker-anchored uninject (clean removal, byte-identical to pre-inject state modulo a trailing newline).
- Fall-back-to-backup uninject when the marker is absent.
- Fragment lookup priority: env override → repo-local `CLAUDE-fragment.md` → handbook source-of-record.
- Honest empirical claims published unredacted (E1 recall test transcripts in `evals/runs/`).

## Rejects

- Modifying global config (`~/CLAUDE.md`, `~/.claude/`, etc).
- Auto-invoking `hermes-ground` or any other companion tool. The fragment teaches the orchestrator *when* to call; it does not call.
- Adding runtime dependencies beyond bash + coreutils.
- Shipping a noun-phrase label for any session-priming concept that does not have files at a path. The repo name `hermes-prime` is acceptable because files now exist.
- Making empirical claims unverified by `evals/runs/` transcripts.
- Auto-pruning backup files. Retention is the user's call.

## Non-goals (v0.1.x)

- Replacing `hermes-ground` (different layer; hermes-prime primes, ground measures).
- Replacing `hermes-rubric` (different layer; hermes-prime primes, rubric scores).
- Replacing `hermes-blind` (different layer; hermes-prime runs before drift, blind runs after).
- Cross-session state (each session that wants the conventions has to inject or read the fragment).
- Auto-refresh on memory-file change (re-inject manually).
- Generation-task convention-injection beyond what the four standing-feedback files cover.

## Design invariants

1. **Mechanism is testable in isolation.** `test-bootstrap.sh` runs without `claude-cli` available and asserts the 9 mechanism properties.
2. **Empirical claim is testable end-to-end.** `evals/preliminary-bootstrap-eval.sh` runs against `claude --print` and reports recall rates with raw transcripts.
3. **Calibrate before ship.** The eval scoring script is dry-tested with synthetic Y/N/partial responses before being run on real transcripts.
4. **Honest null result.** If E1 returns null on a larger sweep, the result is published. The package gets archived if the mechanism doesn't move the recall needle.
5. **No silent fragment changes.** Any change to `CLAUDE-fragment.md` bumps the CHANGELOG and re-runs the seal.
6. **Marker is the contract.** Edits to injected content inside a project's CLAUDE.md (between markers) will be wiped on `--uninject`. Don't edit there.
7. **Source-of-record stays in the handbook.** The repo-local fragment is a copy for portability; the handbook copy is the source-of-record (separate, private, internal).
8. **Sealed at release.** `.hermes-seal.yaml` is signed before each public push. `hermes-seal verify .` exits 0 on the published commit.

## What "done" means for v0.1.0

- 9/9 unit assertions pass on macOS and Linux.
- E1 produces actual recall numbers (positive, partial, or null) with raw transcripts committed.
- E2 and E3 pass.
- `hermes-seal verify .` exits 0.
- Repo public on `hermes-labs-ai/hermes-prime`, README opening line ≤120 chars, badge block live.
