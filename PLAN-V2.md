# hermes-prime v0.2 plan — self-contained fragment + paid-tier seed

> **Strategic call (Roli, 2026-04-26):** ship hermes-prime as fully free OSS
> with the Hermes Labs convention stack inlined into the fragment (showcase
> tech via dogfooding). The adaptive tier — extracting users' own
> conventions from their session history — becomes the paid service later.
> Same binary, two fragment-content tiers: the free one is opinionated
> Hermes Labs, the paid one is custom-generated per user.
>
> Tonight's job: redesign v0.2 so the free tier actually works for non-Roli
> users. Currently the fragment points at memory files + bin paths that
> don't exist on anyone else's machine. **Translate the convention
> pointers into inline scaffold content.**
>
> Verb correction: the v0.2 framing is "stabilize" (drift-prevention), not
> "accelerate." Honest framing makes E1 claims defensible.

## Function this v0.2 performs

A fresh Claude Code session, opened on a project that has been bootstrapped
via `hermes-session-init --inject .`, sees in its CLAUDE.md a complete,
self-contained convention card describing four discipline rules
(grounding, calibration, BLINDed rubric pass-through, no-noun-phrase) —
each with its own definition, trigger conditions, and example. The session
does not need access to ANY external file. The fragment is the entire
artifact.

## Critical change vs v0.1

| v0.1 (current) | v0.2 (proposed) |
|---|---|
| References `feedback_grounding_when_emergent.md` by filename | Inlines the rule's full text + when-to-apply criteria |
| References `~/bin/hermes-ground` | Describes the function ("invoke a fresh-context external review when..."); user implements or installs separately |
| `--check` requires 4 of Roli's memory files | `--check` only verifies `hermes-session-init` itself + reads the fragment file from repo |
| Tool map points at Roli-specific paths | Tool map names function-classes ("an external grounding agent"), points at the official hermes-* tools as one fulfillment of each function |
| Implies universal applicability | Frames explicitly as "this is the Hermes Labs convention stack — adapt or replace" |

## Self-contained fragment — content shape (v0.2 draft)

Each of the four conventions becomes its own self-contained section
inside the fragment, with this template:

```
### Convention: <name>
**The rule:** <one-sentence definition>
**When to apply:** <bulleted trigger conditions>
**What it prevents:** <failure mode in one sentence>
**Mechanical form (recommended):** <how to operationalize — could be a
  tool name we ship, OR a manual practice the user can do themselves>
**Why we (Hermes Labs) follow it:** <one-sentence story / origin>
```

Five sections total: the four conventions + a short "scope of this card"
opener that says explicitly *"this is the Hermes Labs convention stack we
use ourselves; adapt to your context."*

Fragment grows from ~50 lines to ~120-150. Still well under the 8000-char
target window.

## What v0.2 does NOT change

- The bash mechanism (4 subcommands, marker-anchored, idempotent, backup).
  The mechanism is correct; only fragment content changes.
- The HTML-comment markers (`<!-- session-init: BEGIN/END -->`) — keeps
  uninject behavior byte-clean.
- Test structure (9/9 mechanism assertions stay).
- The repo at `hermes-labs-ai/hermes-prime` (no rename, no relocate).
- Public visibility (already public).

## Verification contract for v0.2

1. `--check` succeeds on a *fresh* machine with no Hermes Labs memory files
   or `~/bin/` Hermes binaries. Test: spin a clean Docker container, install,
   run `--check`, expect exit 0.
2. The fragment, when injected, contains complete actionable text for each
   of the four conventions. A reader cannot need to open any other file to
   understand the rule.
3. E1 convention-recall test re-runs cleanly on the v0.2 fragment with
   non-Roli LLM (e.g., Haiku without `--exclude-dynamic-system-prompt-sections`
   pointing at Roli's paths). Same direction-of-effect expected; magnitude
   may shift.
4. All v0.1 mechanism tests (9/9) continue passing.

## Paid-tier seed (sketched, NOT built in v0.2)

The paid adaptive service builds on top of v0.2 by:

1. Reading the user's recent session history (Claude Code jsonl logs)
2. Identifying recurring drift patterns specific to their work
3. Generating a custom fragment with their own conventions, their own
   trigger conditions, their own tool-map paths
4. Same `--inject` mechanism, custom content

For v0.2 we just ensure the fragment-loading path supports an environment
variable or CLI override pointing at a custom fragment file
(`HERMES_SESSION_INIT_FRAGMENT=/path/to/custom.md`) — already implemented
in v0.1 actually (`bin/hermes-session-init` line 14-17 reads
`HERMES_SESSION_INIT_FRAGMENT` env var first). **No code change needed.**
The paid service just produces a different fragment file.

## Migration path v0.1 → v0.2

1. Write the new self-contained fragment as `CLAUDE-fragment.md` in repo root
2. Keep the old reference-laden fragment archived at `CLAUDE-fragment-v1-handbook-pointers.md`
3. Update `--check` to no longer require Roli-specific memory file paths
4. Update README to lead with the verb-correction ("stabilize, not accelerate") and the "Hermes Labs stack — adapt or replace" framing
5. Bump version to 0.2.0
6. CHANGELOG entry citing the lane-shift origin (drift-prevention vs acceleration framing distinction)
7. Re-run E1 on the new fragment, n>1 trial this time
8. Tag + push

## Risks / open questions

- **R1 — Convention longevity.** The four conventions came from one 6-hour
  session's pain. If Hermes Labs encounters new conventions in the next
  month, the fragment needs versioning. v0.3 will add a version field.
- **R2 — User customization friction.** Even with v0.2's framing, users
  installing the OSS get an opinionated card. If they want to customize,
  they have to know about the env-var override. Should be in the README's
  quickstart, not just the source code.
- **R3 — Marketing overlap with the paid tier.** If the free tier is "our
  conventions" and the paid tier is "your conventions, extracted," the
  positioning is clean. If we let the free tier creep toward template-mode,
  it cannibalizes the paid tier's wedge. **Hold the free tier opinionated.**

## Verb correction — README framing

Current README opening: "Pump-prime a fresh Claude Code session with the
conventions you keep forgetting at minute 30."

Proposed v0.2 opening: "**Stop your fresh Claude Code session from drifting
in its first 30 minutes.** Inject a self-contained convention card so the
session opens with grounding triggers, calibration discipline, and the
no-naming-before-implementation rule already in scope. Hermes Labs ships
ours; here's the card we use ourselves. Fork to taste, or pay us to
extract yours."

(Tighter on the "stabilize not accelerate" verb. Honest about the dogfood
+ paid-tier story.)

## Effort estimate

- Self-contained fragment authoring: 2-3 hr (write the four convention sections inline)
- Update --check + README: 1 hr
- Re-run E1 on fresh container: 1-2 hr
- Test passes: 30 min
- Commit + tag: 15 min
- Total: half-day to v0.2 ship.

## Pre-registered decision rule for the rubric on this plan

If the rubric scores ≥6 with majority dims at structural cap → ship
v0.2 as-designed; queue the half-day build for tomorrow.
If <6 with real (uncapped) gaps → iterate the plan once, max 1 retry.
If <6 with all-hedged out-of-scope rationales (the "fix-proposal scope
class doesn't exist" pattern) → ship anyway as proof-of-concept, log
the meta-finding as another scope-class registry gap data point.
