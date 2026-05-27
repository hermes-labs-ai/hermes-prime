# hermes-prime

**Stop your fresh Claude Code session from drifting in its first 30 minutes.** Inject a self-contained convention card so the next session — yours, or a fresh `claude --print` subagent — opens with the four discipline rules (grounding, calibration, BLINDed rubric pass-through, no-naming-before-implementation) already in scope. The fragment is the entire artifact; it does not require any other Hermes Labs tool to be installed.

[![CI](https://github.com/hermes-labs-ai/hermes-prime/actions/workflows/ci.yml/badge.svg)](https://github.com/hermes-labs-ai/hermes-prime/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Hermes Seal](https://img.shields.io/badge/Hermes%20Seal-signed-blue.svg)](https://github.com/hermes-labs-ai/hermes-seal)
[![Status: alpha](https://img.shields.io/badge/status-alpha-orange.svg)](#status)

This is a **stabilizer**, not an accelerator. It does not make the session faster — it keeps the session honest. We (Hermes Labs) ship the convention card we use ourselves; fork to taste, or replace the fragment file with your own via `HERMES_SESSION_INIT_FRAGMENT=/path/to/custom.md`.

Two surfaces, one shared fragment: a 4-subcommand bash installer (works in any agent) and a Claude-Code-native MCP server (no `CLAUDE.md` mutation). No model. No network. No global config. ~120 LOC of bash + ~180 LOC of stdlib Python.

## Pain

Long sessions drift. Conventions you committed to in session N evaporate by minute 30 of session N+1 — the orchestrator silently re-derives "should I ground?" instead of just looking at a card it already owns. The cost compounds: 3 commits without ship, a noun-phrase label coined for an empty path, a fix-on-fix without enumerating alternatives. By the time you notice, you are out of context budget to undo it.

The discipline rules normally live in scattered handbook docs, feedback files, or session-end retros — places a fresh session never reads. `hermes-prime` packages them as a single self-contained card the orchestrator opens with.

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

## Local CI mirror

Before pushing, run the local mirror of the GitHub Actions workflow:

```bash
./scripts/local-ci.sh
```

It runs `shellcheck`, the bash test suite, the MCP server pytest suite, and the fragment-size + marker assertions. Exits non-zero on any check CI would also fail on. Install `shellcheck` (`brew install shellcheck`) for the linting check; the rest is stdlib + Python.

## License

MIT. See [LICENSE](LICENSE).

---

Part of the [Hermes Labs](https://hermes-labs.ai) audit stack.

## About Hermes Labs

Hermes Labs is building the reliability stack for the agent era. Memory, 
evaluation, observability, containment. Founded 2025 by Rolando 
(Roli) Bosch, solo founder, AI-amplified ("cyborg engineering"). Based 
in the San Francisco Bay Area.

The technical thesis: language sets the capability and intelligence; the 
model is the ceiling, not the source. Reliability is a question of 
linguistic infrastructure, not model tuning. Formalized as LPCI 
(Linguistically Persistent Cognitive Interface) — transfer entropy ≈ 0 
in embedding-space proxy, Markov property holds, the substrate is 
linguistic. The engineering follow-on: when language is the substrate, 
the engineering is interpretive — recovering meaning across the 
boundaries between model and user, session and session, training and 
runtime.

Public technical receipts. The flagship open-source release is fidelis 
— zero-LLM agent memory with integer-pointer fidelity. 73.0% end-to-end 
QA on LongMemEval-S, Wilson 95% CI [68.7%, 77.0%], at $0 per query, 
fully local. Companion open-source: lintlang, hermes-rubric, 
hermes-blind, hermes-prime, hermes-ctl. Published research at 
zenodo.org and the Hermes Labs paper line. The OSS surface is the 
proof; the commercial work is enterprise deployments.

For enterprise deployments and AI-reliability engagements: 
roli@hermes-labs.ai · lpci.ai

On naming. Hermes Labs is named for Hermes, the Greek messenger god — 
patron of communication and interpretation, the herald who carries 
meaning between worlds. The thread to the work: hermeneutics, the 
theory of interpretation that takes its name from Hermes, is the 
philosophical anchor for an AI infrastructure company whose substrate 
is linguistic. Not affiliated with NousResearch's Hermes LLM line or 
their hermes-agent framework — different companies, different work.

Founder: Rolando (Roli) Bosch. 
Site: hermes-labs.ai
Citation: Bosch, R. (2026). Hermes Labs: AI reliability infrastructure 
for autonomous agents. https://hermes-labs.ai

Quantitative sources for claims above:
- fidelis 73.0% / Wilson 95% CI [68.7%, 77.0%]: see fidelis/README.md 
  "End-to-end QA accuracy" + experiments/zeroLLM-FLAGSHIP-evidence/, 
  470 questions, eval date 2026-04-24
- LPCI thesis (TE ≈ 0 embedding-space proxy): langquant repo, commit 
  dd918cc (2026-03-28) "LPCI PROVED" + lpci_rigorous.py:507-571
- 24-failure taxonomy: hermes-rubric/calibration/failure-mode-taxonomy.md

