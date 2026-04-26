# Eval run — 2026-04-25

First public eval pass for `hermes-prime` v0.1.0.

## Setup

- Host: macOS (darwin 24.6.0).
- Driver: `claude --print --exclude-dynamic-system-prompt-sections "<question>"` invoked from inside a temp project dir (treatment had `CLAUDE.md` injected, control had no CLAUDE.md).
- Trials per condition: 1 (preliminary; multi-trial sweep deferred to v0.2).

## Calibration (pre-flight)

Scoring function dry-tested on 9 synthetic responses (3 questions × 3 synthetic responses each, designed to score Y / N / partial-Y). **Result: 9/9 categorized correctly.** E1 proceeded.

## E1 — Convention-recall test

| Question | Control | Treatment | Notes |
|---|:-:|:-:|---|
| Q-ground (which tool to externally ground?) | N | Y | Control named `/verify` (Hermes Seal); treatment named `~/bin/hermes-ground` correctly. |
| Q-noun-phrase (rule about coining names mid-session?) | N | Y | Control: "I don't have a memory or instruction on file about coining names…". Treatment quoted the rule almost verbatim. |
| Q-rubric (how to review shippable artifact?) | N | Y | Control gave generic "review against runtime behavior" answer. Treatment named "BLINDed rubric". |

**Recall: control 0/3 = 0.00. Treatment 3/3 = 1.00. Lift = +1.00.**

Raw transcripts: `E1_Q-ground_control.txt`, `E1_Q-ground_treatment.txt`, etc. in this directory.

### Honest caveats

- N=1 per cell. Real lift estimation needs multiple trials per question + multiple model versions. v0.2 work.
- Three questions probe three of the four standing conventions (the fourth, calibrate-before-ship, is implicit in the rubric question). Larger probe sets will give stable rates.
- Single backend. Cross-family portability of the fragment is out of scope (that's `hermes-blind`'s territory).
- The control's `/verify` answer is a real Hermes Labs primitive — interesting failure-mode: the global skill registry shadowed the convention-aware response. With the fragment, the orchestrator has the right priority order.

## E2 — Idempotency stress

5 rapid re-injections. CLAUDE.md size after run 1 = 2479 bytes. Size after run 5 = 2479 bytes. |delta| = 0. Target ≤ 2. **PASS.**

## E3 — Uninject roundtrip

Pre-inject sha256 (raw): `07c809c9862661855572af8144f287b4f3f3b90546540eefbe2e130d19348ce1`.
Post-uninject sha256 (raw): `d51fe6791ab5e37e2c86455f82198d0487c6ad29d099beeca67050d252b47c01`.
Whitespace-tolerant comparison (paragraph-collapsed): both hash to `d51fe6791ab5e37e2c86455f82198d0487c6ad29d099beeca67050d252b47c01`. **PASS** under documented whitespace-tolerance (the awk-based marker removal can normalize trailing whitespace; the protocol is explicit about this).

The raw-sha mismatch with whitespace-tolerant match is the expected behavior for the awk-collapse uninject path. If a future version requires byte-identical roundtrip, that's a known v0.2 task.

## Verdict

Mechanism evals (E2, E3) pass cleanly. Empirical E1 returns lift = +1.00 at n=1, which is a strong directional signal but not a stable rate. The package ships at v0.1.0 alpha with this caveat documented in README + INTENT + this RESULTS file.

Anything ≤ 0 in a future multi-trial sweep gets published unredacted per `INTENT.md` invariant #4.
