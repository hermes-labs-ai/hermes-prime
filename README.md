# hermes-prime

**Pump-prime a fresh Claude Code session with the conventions you keep forgetting at minute 30.**

[![CI](https://github.com/hermes-labs-ai/hermes-prime/actions/workflows/ci.yml/badge.svg)](https://github.com/hermes-labs-ai/hermes-prime/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Hermes Seal](https://img.shields.io/badge/Hermes%20Seal-signed-blue.svg)](https://github.com/hermes-labs-ai/hermes-seal)
[![Status: alpha](https://img.shields.io/badge/status-alpha-orange.svg)](#status)

A small bash bootstrap that injects a versioned `CLAUDE.md` fragment into a project so the next session — yours, or a fresh `claude --print` subagent — opens with the conventions already loaded: when to call external grounding, where the audit-stack tools live, and the standing rules (calibrate-before-ship, rubric pass-through, no-noun-phrase-before-file).

It is a markdown fragment plus a 4-subcommand bash installer. No model. No network. No global config. ~120 LOC.

## Pain

Long sessions drift. Conventions you committed to in session N evaporate by minute 30 of session N+1 — the orchestrator silently re-derives "should I ground?" instead of just looking at a card it already owns. The cost compounds: 3 commits without ship, a noun-phrase label coined for an empty path, a fix-on-fix without enumerating alternatives. By the time you notice, you are out of context budget to undo it.

The conventions live in your handbook and in feedback memory files. The orchestrator never sees them in a fresh session.

## How it's different

Most "set up the agent" tools either (a) ship a giant prompt file you copy-paste, or (b) install a global hook that runs on every session whether you want it or not. `hermes-prime` is per-project, marker-anchored, idempotent, fully reversible, and snapshots the conventions into the repo's own `CLAUDE.md` so they ride along with the code.

The fragment is a snapshot, not a live reference. Re-inject to refresh. The marker (`<!-- session-init: BEGIN/END -->`) means uninject is byte-clean.

## Two surfaces

| Surface | Audience | Mechanism |
|---|---|---|
| **MCP server** (recommended for Claude Code) | Claude Code users | Native MCP tools — `get_conventions` / `list_scopes`. No `CLAUDE.md` mutation, no snapshot. See [`mcp-server/`](mcp-server/). |
| **Bash binary** (universal fallback) | Cursor, Aider, raw scripts, CI, non-Claude-Code agents | Inject the fragment into a project's `CLAUDE.md` between markers. Snapshot semantics — re-inject to refresh. |

Both share the same `CLAUDE-fragment.md`. They are independent surfaces; pick whichever fits your agent.

## MCP server (Claude Code native)

```bash
claude mcp add hermes-prime -- python3 "$PWD/mcp-server/hermes_prime_mcp.py"
```

Then call `get_conventions` from any Claude Code session. Pure stdlib, no third-party deps. Full registration + uninstall instructions in [`mcp-server/README.md`](mcp-server/README.md).

## Install (bash binary)

```bash
git clone https://github.com/hermes-labs-ai/hermes-prime.git
cd hermes-prime
ln -s "$PWD/bin/hermes-session-init" /usr/local/bin/hermes-session-init
hermes-session-init --check
```

Or symlink into `~/bin/`. No package install — it is one bash script and one markdown fragment.

## Quickstart

```bash
# Verify prereqs (hermes-ground, hermes-rubric-blinded, handbook, 4 memory files)
hermes-session-init --check

# Print the fragment to stdout (pipe-friendly)
hermes-session-init --print

# Inject the fragment into a project's CLAUDE.md (idempotent, backs up existing)
hermes-session-init --inject ~/Documents/projects/some-project

# Remove the fragment cleanly (anchored on the marker)
hermes-session-init --uninject ~/Documents/projects/some-project
```

## What it does

| Subcommand | Behavior | Exit |
|---|---|---|
| `--check` | Verifies hermes-ground, hermes-rubric-blinded, the handbook, the fragment file, and 4 standing-feedback memory files exist. Prints one-line readiness. | 0 ok / 1 missing |
| `--print` | Prints the CLAUDE-fragment to stdout. Useful for piping into `--append-system-prompt` or for inspection. | 0 |
| `--inject <project>` | Appends the fragment to `<project>/CLAUDE.md` between markers. Backs up existing `CLAUDE.md` to `CLAUDE.md.bak.<timestamp>`. Idempotent: re-running is a no-op. | 0 |
| `--uninject <project>` | Removes the marked block. Falls back to latest backup if no marker present. Exits non-zero if neither marker nor backup found — no destructive guessing. | 0 ok / 1 not-found |

## What gets injected

A short markdown block containing:

1. **Grounding triggers** — the 7 conditions under which the orchestrator should call `hermes-ground` for an external reality check.
2. **Convention pointers** — references (not full text) to four standing-feedback memory entries with one-line reminders.
3. **Tool map** — paths for `hermes-ground`, `hermes-rubric-blinded`, the handbook, and this bootstrap.
4. **The rule most often forgotten mid-session** — no noun-phrase label until a file exists at a path.

See [`CLAUDE-fragment.md`](CLAUDE-fragment.md) for the full text. The fragment is the contract.

## Preliminary evals

Three honest evals live in [`evals/`](evals/):

- **E1 — convention-recall test:** does a fresh `claude --print` session injected with the fragment correctly identify `hermes-ground` as the external-grounding tool, vs an un-injected session?
- **E2 — idempotency stress:** inject 5x in a row, assert size delta ≤ 2 chars.
- **E3 — uninject roundtrip:** inject → uninject → assert content matches pre-inject state (whitespace-tolerant).

Run them: `bash evals/preliminary-bootstrap-eval.sh`. Protocol in [`evals/EVAL-PROTOCOL.md`](evals/EVAL-PROTOCOL.md). Run transcripts at [`evals/runs/`](evals/runs/). Null results published unredacted per the standing convention.

## How it relates to the Hermes Labs audit stack

`hermes-prime` is the **session-priming layer** beneath the rest of the Hermes Labs OSS audit stack. It does not replace any of them; it ensures they get called.

- [`hermes-ground`](https://github.com/hermes-labs-ai/hermes-ground) — the fresh-context grounding agent the fragment teaches the orchestrator to invoke. *(companion tool, not in this repo)*
- [`hermes-rubric`](https://github.com/hermes-labs-ai/hermes-rubric) — evidence-first scoring; the convention "every shippable artifact passes through a BLINDed rubric" points here.
- [`hermes-blind`](https://github.com/hermes-labs-ai/hermes-blind) — multi-turn drift correction scaffold; runs *after* drift accumulates. `hermes-prime` runs *before* drift starts.
- [`hermes-seal`](https://github.com/hermes-labs-ai/hermes-seal) — cryptographic attestation. This repo ships a sealed `.hermes-seal.yaml` manifest.

## Status

**v0.1.0 — alpha.** The mechanism (inject/uninject/idempotency) is fully tested (9/9 unit assertions green). The empirical claim — that injecting the fragment measurably improves convention-recall in a fresh session — is the subject of the E1 eval, run on real `claude --print` and committed unredacted. See [`evals/runs/2026-04-25/`](evals/runs/2026-04-25/) for the actual numbers.

If E1 returns a null result on a larger sweep, that gets published, not papered over. Same standing convention as the rest of the audit stack.

## License

MIT. See [LICENSE](LICENSE).

---

Part of the [Hermes Labs](https://hermes-labs.ai) audit stack.
