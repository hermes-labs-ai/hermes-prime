# AGENTS.md — hermes-prime

Guidance for autonomous agents and LLM tooling that may consume, extend, or be primed by this package.

## What this is

A bash bootstrap (`bin/hermes-session-init`) plus a markdown fragment (`CLAUDE-fragment.md`). The bootstrap injects the fragment into a project's `CLAUDE.md` so the next session opens with conventions in scope. Four subcommands: `--check`, `--print`, `--inject`, `--uninject`. ~120 LOC of bash, no Python, no dependencies.

## What this is not

- Not a model, an API, or a judge.
- Not an automatic grounding caller — the fragment teaches the orchestrator *when* to call `hermes-ground`; it does not call it for you.
- Not a global config patcher — it never touches `~/CLAUDE.md`. Per-project only.
- Not a runtime daemon — it runs once per inject; the fragment lives in the project repo from then on.

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
hermes-session-init --check                          # verify prereqs
hermes-session-init --inject /path/to/project        # idempotent
# ... do work ...
hermes-session-init --uninject /path/to/project      # cleanup
```

## What the fragment teaches

After injection, a session reading the project's `CLAUDE.md` will know:

1. **When to call `hermes-ground`** — 7 specific trigger conditions (e.g. "3+ commits without a user-visible ship", "about to coin a noun-phrase label for something with no implementation at a path").
2. **Where the audit-stack tools live** — paths for `hermes-ground`, `hermes-rubric-blinded`, the handbook.
3. **The four standing conventions** — calibrate-before-ship, rubric pass-through, grounding-on-emergence, no-noun-phrase-before-file.

The fragment is a *snapshot* of conventions at injection time. If the underlying memory feedback files change, re-inject to refresh.

## Honest scope

`hermes-prime` does not measure whether the conventions are followed after injection. The companion tool `hermes-ground` does that for grounding. `hermes-rubric` does that for ship-quality. `hermes-prime` only guarantees the conventions are *in scope*.

The empirical claim that injection improves convention-recall in a fresh session is the subject of the E1 eval in `evals/`. Read the eval transcripts in `evals/runs/` for the actual numbers.

## Don't

- Don't auto-inject into every project on a hook. The fragment costs tokens; only inject where the conventions apply.
- Don't modify the fragment in-place inside a project's CLAUDE.md. The marker block is the contract; edits there will be wiped on `--uninject`.
- Don't ship a noun-phrase label for a session-priming concept that does not yet have a file. The repo name is `hermes-prime` because the files now exist; that earned the noun.
