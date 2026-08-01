# hermes-prime

**Deliver a versioned convention card to a fresh Claude Code session.** The
Bash surface snapshots the card into a project's `CLAUDE.md`; the read-only MCP
surface returns the same card over stdio. The mechanism makes conventions
available. It does not prove that a model will follow them or prevent drift.

[![CI](https://github.com/hermes-labs-ai/hermes-prime/actions/workflows/ci.yml/badge.svg)](https://github.com/hermes-labs-ai/hermes-prime/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Status: alpha](https://img.shields.io/badge/status-alpha-orange.svg)](#status)

This is a small transport, not an enforcement layer. Hermes Labs ships the
convention card it uses itself; fork it or select another fragment with
`HERMES_SESSION_INIT_FRAGMENT=/path/to/custom.md`.

Two surfaces share one fragment: a four-subcommand Bash tool for
`CLAUDE.md`-based workflows and a Claude-Code-native MCP server that does not
mutate `CLAUDE.md`. Neither surface calls a model or a network service. The Bash
path makes no global configuration change; MCP registration uses the scope the
user selects.

## Pain

Conventions can fall out of visible context between sessions. A versioned card
gives a new session one concrete artifact to read instead of requiring it to
reconstruct those conventions from scattered notes.

The discipline rules normally live in scattered handbook docs, feedback files, or session-end retros — places a fresh session never reads. `hermes-prime` packages them as a single self-contained card the orchestrator opens with.

## How it's different

Most "set up the agent" tools either (a) ship a giant prompt file you copy-paste,
or (b) install a global hook that runs on every session whether you want it or
not. `hermes-prime` is per-project, marker-anchored, and idempotent. Unedited
injected suffixes are byte-reversible; edited blocks use the documented
marker/backup fallback.

The fragment is a snapshot, not a live reference. Re-inject to refresh. The marker (`<!-- session-init: BEGIN/END -->`) means uninject is byte-clean.

## Two surfaces

| Surface | Audience | Mechanism |
|---|---|---|
| **MCP server** (recommended for Claude Code) | Claude Code users | Native MCP tools — `get_conventions` / `list_scopes`. No `CLAUDE.md` mutation, no snapshot. See [`mcp-server/`](mcp-server/). |
| **Bash binary** (`CLAUDE.md` fallback) | Claude Code and other workflows that explicitly read a project's `CLAUDE.md` | Inject the fragment into `CLAUDE.md` between markers. Snapshot semantics — re-inject to refresh. Other agent instruction formats are not included. |

Both share the same `CLAUDE-fragment.md`. They are independent surfaces; pick whichever fits your agent.

## MCP server (Claude Code native)

```bash
claude mcp add --scope local hermes-prime -- python3 "$PWD/mcp-server/hermes_prime_mcp.py"
```

Run that command from the repository root. Local scope loads the server for the
current project. Use `--scope user` only if you intend to make the same command
available to your own sessions across projects. Then call `get_conventions`
from a session covered by the selected scope. Pure stdlib, no third-party
runtime dependencies. Full registration and removal instructions are in
[`mcp-server/README.md`](mcp-server/README.md).

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
# Require the fragment; report optional companion tools as information
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
| `--check` | Requires only the fragment file. Reports hermes-ground, hermes-rubric-blinded, and the handbook as optional informational companions. | 0 fragment present / 1 fragment missing |
| `--print` | Prints the CLAUDE-fragment to stdout. Useful for piping into `--append-system-prompt` or for inspection. | 0 |
| `--inject <project>` | Appends the fragment to `<project>/CLAUDE.md` between markers. Backs up existing `CLAUDE.md` to `CLAUDE.md.bak.<timestamp>`. Idempotent: re-running is a no-op. | 0 |
| `--uninject <project>` | Removes the exact suffix added by `--inject`, byte-restoring pre-existing content or removing a `CLAUDE.md` created by injection. Falls back to line-preserving marker removal for edited blocks, or the latest backup when no marker remains. | 0 ok / 1 not-found |

## What gets injected

A short markdown block containing:

1. **Grounding triggers** — the 7 conditions under which the orchestrator should call `hermes-ground` for an external reality check.
2. **Self-contained conventions** — calibration, rubric pass-through, grounding, and name discipline.
3. **Tool map** — functional categories, Hermes Labs implementations, and manual fallbacks.
4. **The rule most often forgotten mid-session** — no noun-phrase label until a file exists at a path.

See [`CLAUDE-fragment.md`](CLAUDE-fragment.md) for the full text. The fragment is the contract.

## Preliminary evals

Three honest evals live in [`evals/`](evals/):

- **E1 — convention-recall test:** does a fresh `claude --print` session injected with the fragment correctly identify `hermes-ground` as the external-grounding tool, vs an un-injected session?
- **E2 — idempotency stress:** inject 5x in a row, assert size delta ≤ 2 chars.
- **E3 — uninject roundtrip:** inject → uninject → require identical raw pre/post hashes.

Run them: `bash evals/preliminary-bootstrap-eval.sh`. Protocol in [`evals/EVAL-PROTOCOL.md`](evals/EVAL-PROTOCOL.md). Run transcripts at [`evals/runs/`](evals/runs/). Null results published unredacted per the standing convention.

## How it relates to the Hermes Labs audit stack

`hermes-prime` is a convention-delivery surface in the Hermes Labs OSS audit
stack. It does not replace companion tools and does not ensure that they are
called.

- [`hermes-ground`](https://github.com/hermes-labs-ai/hermes-ground) — the fresh-context grounding agent the fragment teaches the orchestrator to invoke. *(companion tool, not in this repo)*
- [`hermes-rubric`](https://github.com/hermes-labs-ai/hermes-rubric) — evidence-first scoring; the convention "every shippable artifact passes through a BLINDed rubric" points here.
- [`hermes-blind`](https://github.com/hermes-labs-ai/hermes-blind) — a separately invoked multi-turn recovery scaffold.

## Status

**Source version 0.2.1-alpha.1 — unreleased alpha candidate.** There is no public
0.2.1-alpha.1 tag or GitHub release, and this branch does not authorize one. The
mechanism suite contains 11 Bash assertions plus 10 MCP tests. E1 is one
author-run three-question control/treatment observation; it is preliminary
convention-recall evidence, not evidence that the tool prevents drift or
improves downstream task performance.

If E1 returns a null result on a larger sweep, that gets published, not papered over. Same standing convention as the rest of the audit stack.

## Local mechanism gate

Before requesting any push or release, run the local mechanism gate:

```bash
./scripts/local-ci.sh
```

It runs ShellCheck, the 11-assertion Bash suite, the 10-test MCP suite, and
fragment size/marker checks. The proposed hosted workflow also runs MCP tests
on macOS and Ubuntu. Exit 0 is evidence only for those named checks at the
current tree; it is not push, release, or publication authorization.

## License

MIT. See [LICENSE](LICENSE).

---

Part of the [Hermes Labs](https://hermes-labs.ai) audit stack.

## About Hermes Labs

Hermes Labs builds evidence-oriented, local-first infrastructure for agent
memory, evaluation, and workflow reliability. This repository is one small
mechanism in that portfolio; its claims are limited to behavior exercised by
the checks above.

For enterprise deployments and AI-reliability engagements: 
roli@hermes-labs.ai · hermes-labs.ai

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
