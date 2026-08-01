# AGENTS.md — hermes-prime

Guidance for autonomous agents and LLM tooling that may consume, extend, or be primed by this package.

## What this is

Two local surfaces share `CLAUDE-fragment.md`: a Bash bootstrap that injects
the card into a project's `CLAUDE.md`, and a stdlib Python MCP server that
returns it over stdio. The Bash surface has four subcommands: `--check`,
`--print`, `--inject`, and `--uninject`; the MCP surface has two read-only
tools. Source version `0.2.1-alpha.1` is an unreleased candidate, not a public release.

## What this is not

- Not a model, an API, or a judge.
- Not an automatic grounding caller — the fragment teaches the orchestrator *when* to call `hermes-ground`; it does not call it for you.
- Not a global config patcher — it never touches `~/CLAUDE.md`. Per-project only.
- Not a drift-prevention guarantee — delivery is tested; downstream adherence is not.
- Not a runtime daemon — Bash runs once per inject; MCP is a host-launched stdio process.

## When to invoke (as an agent)

Use `hermes-session-init --inject <project-dir>` when:

- You are starting recursive or emergent work in a fresh project (taxonomy design, rubric construction, structure-discovery debugging) AND
- The project's `CLAUDE.md` does not yet contain the marker `<!-- session-init: BEGIN -->`.

Skip if:

- The session is a single-task fix (the fragment adds noise without payoff).
- The project's `CLAUDE.md` already has the marker (`--inject` is a no-op anyway, but skip the call).
- The work is generation-task only with no rubric or grounding loop.

## Minimal invocation

```bash
hermes-session-init --check                          # require fragment; report optional companions
hermes-session-init --inject /path/to/project        # idempotent
# ... do work ...
hermes-session-init --uninject /path/to/project      # cleanup
```

## What the fragment teaches

After injection, a session reading the project's `CLAUDE.md` will know:

1. **When to call `hermes-ground`** — 7 specific trigger conditions (e.g. "3+ commits without a user-visible ship", "about to coin a noun-phrase label for something with no implementation at a path").
2. **Where the audit-stack tools live** — paths for `hermes-ground`, `hermes-rubric-blinded`, the handbook.
3. **The four standing conventions** — calibrate-before-ship, rubric pass-through, grounding-on-emergence, no-noun-phrase-before-file.

The fragment is a *snapshot* of conventions at injection time. Re-inject to
refresh after changing the repository fragment.

## Honest scope

`hermes-prime` does not measure whether conventions are followed after
delivery. It proves only the tested transport behavior: MCP returns a selected
card, and unedited Bash injection can be reversed to the original bytes.

The empirical claim that injection improves convention-recall in a fresh session is the subject of the E1 eval in `evals/`. Read the eval transcripts in `evals/runs/` for the actual numbers.

## Don't

- Don't auto-inject into every project on a hook. The fragment costs tokens; only inject where the conventions apply.
- Don't modify the fragment in-place inside a project's CLAUDE.md. The marker block is the contract; edits there will be wiped on `--uninject`.
- Don't ship a noun-phrase label for a session-priming concept that does not yet have a file. The repo name is `hermes-prime` because the files now exist; that earned the noun.
