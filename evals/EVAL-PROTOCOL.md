# Eval Protocol — hermes-prime v0.1.0

Three preliminary evals. E1 is the empirical claim test; E2 and E3 are mechanism tests that don't require `claude-cli`.

## E1 — Convention-recall test (with vs without bootstrap)

### Hypothesis

A fresh `claude --print` session running in a project with the hermes-prime fragment injected into `CLAUDE.md` will name `hermes-ground` (and other audit-stack tools / conventions) more often than the same session running in a project with no `CLAUDE.md`.

### Setup

- Driver: `cd <project-dir> && claude --print --exclude-dynamic-system-prompt-sections "<question>"`
- Reason for `--exclude-dynamic-system-prompt-sections`: removes per-machine memory paths and global CLAUDE.md from the system prompt, so the *only* convention source is the project-local `CLAUDE.md` (auto-discovered from cwd).
- `cd <project-dir>` (not `--add-dir`) is the right primitive — `--add-dir` is variadic and would consume the trailing prompt arg.

### Conditions

- **Without bootstrap (control):** temp project dir, no `CLAUDE.md`.
- **With bootstrap (treatment):** same temp project, `hermes-session-init --inject` run before the prompt.

### Questions (3 distinct convention probes)

1. **Q-ground** — "What tool would I run to externally ground a drifting session? Reply in one sentence."
   - Pass: response names `hermes-ground` (literal substring match, case-insensitive).
2. **Q-noun-phrase** — "What is the rule about coining names for new concepts mid-session? Reply in one sentence."
   - Pass: response mentions "no noun-phrase" OR "file exists at a path" OR "until a file" (case-insensitive substring).
3. **Q-rubric** — "How should every shippable artifact be reviewed before ship? Reply in one sentence."
   - Pass: response names `hermes-rubric` OR mentions "BLIND"/"blinded rubric"/"rubric pass-through" (case-insensitive).

### Scoring

Each question is binary Pass/Fail per response. Recall rate = passes / questions, per condition. Report:

- Per-question outcome (Y/N) for control and treatment.
- Per-condition recall rate.
- Lift = treatment_recall − control_recall.

### Calibration

Before running on real `claude-cli`, the scoring function is dry-tested with three synthetic responses per question (one designed to score Y, one N, one partial-Y/edge case). The dry-test must categorize all 9 (3 questions × 3 synthetic responses) correctly before E1 runs against the live model. The dry-test is run as the first step of `preliminary-bootstrap-eval.sh`.

### Honest reporting

If recall lift is ≤0 (the bootstrap doesn't help, or hurts), the result is published unredacted and the package status is downgraded. This follows the binding null-result convention from `INTENT.md` invariant #4.

### Limitations (v0.1.0)

- N=1 trial per condition. Real lift estimation needs multiple trials × multiple model versions; that's v0.2 work.
- Three questions only. Larger probe sets needed for stable rates.
- Single backend (whatever `claude --print` resolves to). Cross-family portability is out of scope here; that's `hermes-blind`'s territory.
- Dynamic-system-prompt-section exclusion changes per-machine state; results may not generalize to default-mode sessions.

## E2 — Idempotency stress (rapid re-injection)

### Setup

- Create temp project dir.
- Run `hermes-session-init --inject <tmpdir>` 5 times consecutively.
- Measure CLAUDE.md byte size after run 1 and after run 5.

### Pass condition

`abs(size_after_5 - size_after_1) <= 2` bytes (tolerance for trailing newline normalization).

### Why this matters

Repeated injection in CI loops or multi-agent orchestrators must not snowball CLAUDE.md size.

## E3 — Uninject roundtrip integrity

### Setup

- Create temp project dir with a known pre-existing `CLAUDE.md` containing arbitrary content.
- Compute `sha256(CLAUDE.md)` → `pre_hash`.
- Run `hermes-session-init --inject <tmpdir>`.
- Run `hermes-session-init --uninject <tmpdir>`.
- Compute `sha256(CLAUDE.md)` → `post_hash`.

### Pass condition

`pre_hash == post_hash` after normalizing trailing whitespace (the awk-based marker removal can leave or strip a trailing newline depending on file shape; whitespace-tolerant comparison is documented and explicit).

### Why this matters

The bootstrap is reversible. A user who runs `--inject` and changes their mind must get back exactly what they started with.
