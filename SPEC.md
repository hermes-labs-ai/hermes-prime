# session-init — spec

## What this is

A small bootstrap that primes a fresh Claude Code session with the conventions
required for recursive/emergent work: when to invoke external grounding, where
the relevant tools live on disk, and which standing rules apply (calibrate
before ship, rubric pass-through, no noun-phrase before file). It is a
markdown fragment plus a bash installer. It does not run any model, does not
call grounding for you, and does not modify any global config.

## When to use it

- Starting a new project that is expected to do recursive/structure-discovery
  work (e.g. designing a taxonomy, building a rubric, debugging an emergent
  failure mode).
- Restarting a long session in a new context where the prior session's
  conventions need to carry over but the auto-loaded CLAUDE.md does not yet
  know about them.
- Onboarding a fresh `claude --print` or sub-session that needs the same
  conventions the parent session is operating under.
- Any session where the cost of the orchestrator silently re-deriving "should
  I ground?" is higher than the ~30 lines of injected primer.

Do **not** use it on short single-task sessions where the conventions add
noise without payoff.

## What it injects

1. The grounding-triggers card (summary of `~/bin/hermes-ground-triggers.md`,
   including the call-conditions verbatim).
2. Convention pointers — references to the four standing-feedback memory
   entries (`feedback_grounding_when_emergent.md`,
   `feedback_calibrate_analysis_before_ship.md`,
   `feedback_rubric_blind_passthrough_default.md`,
   `feedback_no_noun_phrase_before_file.md`) with one-line reminders.
3. A tool map — where `hermes-ground`, `hermes-rubric-blinded`, the handbook,
   and the trigger card live.
4. A startup self-check (`hermes-session-init --check`) that verifies the
   above paths exist and prints a single-line readiness report.

## What it does NOT do

- Does **not** invoke `hermes-ground` automatically. Triggers are listed; the
  orchestrator still has to call the tool.
- Does **not** override the user's `~/CLAUDE.md` or any project's existing
  CLAUDE.md content. It appends a marked block; existing content is
  preserved.
- Does **not** cross sessions. Each session that wants the conventions has to
  inject (or read) the fragment.
- Does **not** auto-update the conventions when the underlying memory
  feedback files change. The fragment is a snapshot; re-inject to refresh.
- Does **not** ship a noun-phrase label for itself. Refer to it by function
  ("the bootstrap", "session-init") until the files have proven their worth.

## Verification contract

A user knows the bootstrap worked when:

- `hermes-session-init --check` exits 0 and prints
  `OK: prereqs present (hermes-ground, hermes-rubric-blinded, 4 memory files, handbook)`.
- `hermes-session-init --inject <project-dir>` exits 0 and the project's
  `CLAUDE.md` now contains the marker comment
  `<!-- session-init: BEGIN -->` and the fragment body.
- A backup file `CLAUDE.md.bak.<timestamp>` exists alongside the modified
  `CLAUDE.md` (when the file already existed before injection).
- Re-running `--inject` is a no-op (no double fragment, exit 0).

If any check fails, exit code is non-zero and stderr names the missing
component.

## Rollback

```bash
hermes-session-init --uninject <project-dir>
```

Removes the marked block (anchored on `<!-- session-init: BEGIN -->` /
`<!-- session-init: END -->`). If the marker is absent but a backup
`CLAUDE.md.bak.<timestamp>` exists, restores from the most recent backup. If
neither marker nor backup is present, exits non-zero with a clear message —
no destructive guessing.

Backup files are timestamped `CLAUDE.md.bak.YYYYMMDD-HHMMSS` and are not
auto-pruned. The user manages retention.

## Open design questions

These are honestly open and not blocking the v0.1 build:

1. **Snapshot vs live reference.** The fragment currently snapshots the
   trigger card. Should it instead `source` or `cat` the live
   `~/bin/hermes-ground-triggers.md` at session start so updates propagate?
   Trade-off: live = always current, but adds a runtime dependency the
   project repo cannot vendor.
2. **Per-project vs global.** Right now this is per-project (CLAUDE.md
   append). Should there also be a `--global` mode that writes into
   `~/CLAUDE.md`? Risk: every session pays the token cost even when the
   conventions don't apply.
3. **Auto-call on emergence.** Should the bootstrap also install a hook that
   auto-runs `hermes-ground` when N expand-without-ship moves accumulate?
   Currently deferred — auto-call could fire on false positives and burn
   user trust.
4. **Refresh signal.** No mechanism warns the user when the underlying
   memory feedback files change after injection. A `--diff` mode comparing
   injected fragment to current source-of-truth would close this gap.
