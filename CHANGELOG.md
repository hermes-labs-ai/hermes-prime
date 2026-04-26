# Changelog

All notable changes to `hermes-prime` will be documented in this file. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

## [0.2.0] — 2026-04-26

Reframed v0.2 — same mechanism, updated framing and self-contained fragment.

### Changed

- **Verb correction.** Reframed README from "pump-prime / accelerator" to **stabilizer** — the tool keeps a fresh session honest, it does not make it faster. Honest framing makes the empirical claims (E1 convention-recall) defensible.
- **Self-contained fragment.** `CLAUDE-fragment.md` rewritten so each of the four conventions (grounding, calibration, BLINDed rubric pass-through, no-noun-phrase) is fully inlined: rule, when-to-apply, what-it-prevents, mechanical form, and origin story. No more pointers to user-missing memory files (`feedback_*.md`). The fragment is now the entire artifact; non-Roli users do not need any other Hermes-Labs file installed for the rules to apply.
- **`--check` no longer demands Hermes-Labs companion tools.** Now verifies only that the bootstrap and fragment file exist; reports companion-tool presence as informational. Lets the bash binary `--check` succeed on a fresh machine with no `~/bin/hermes-*` binaries.
- **Tool map describes function-classes, not paths.** The fragment names what each function does (fresh-context grounding agent, synthetic-truth calibration, debiased rubric pass) and lists Hermes Labs tools as *one* fulfillment. Manual fallbacks are listed alongside.
- **README opener** explicitly frames as "the convention stack we use ourselves; adapt or replace" and points at the `HERMES_SESSION_INIT_FRAGMENT` env override.

### Verified

- Bash test suite: 9/9 PASS unchanged.
- MCP server tests: 10/10 PASS unchanged.
- Bash `--check` exits 0 on a clean repo with only the fragment file present (the v0.2 contract).

### Why

v0.1 implicitly assumed a Roli-installed environment. The v0.2 framing makes the free-OSS surface honest: anyone can install this bash tool on a fresh machine and `--check` will pass. The custom-conventions story (extracting a user's own conventions from session history) becomes the future paid-tier wedge — same binary, different fragment file via the env override that already exists.

## [0.1.0] — 2026-04-25

Initial public release. Promoted from internal handbook scaffolding to its own repo after the bootstrap proved out across multiple sessions.

### Added

- `bin/hermes-session-init` — bash bootstrap with four subcommands (`--check`, `--print`, `--inject`, `--uninject`). Idempotent; marker-anchored; backups created on existing `CLAUDE.md`.
- `CLAUDE-fragment.md` — the markdown block injected into target projects. Contains grounding triggers, convention pointers (4 feedback memory files), tool map, and the no-noun-phrase rule.
- `SPEC.md` — function spec, verification contract, rollback semantics, open design questions.
- `test-bootstrap.sh` — 9-assertion test suite for the bash binary. All green at v0.1.0.
- `evals/preliminary-bootstrap-eval.sh` — three preliminary evals (E1 convention-recall, E2 idempotency stress, E3 uninject roundtrip).
- `evals/EVAL-PROTOCOL.md` — eval protocol, prompt templates, scoring rubric.
- `evals/runs/2026-04-25/` — initial eval run transcripts (unredacted).
- `INTENT.md` — invariants, accepts/rejects/non-goals.
- Standard repo polish: README, LICENSE (MIT), CITATION.cff, AGENTS.md, llms.txt, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CHANGELOG, .github/workflows/ci.yml, .gitignore.
- `.hermes-seal.yaml` — sealed manifest (signed at release).

### Changed

- The bash binary's fragment-lookup logic now prefers a repo-local `CLAUDE-fragment.md` (when invoked from `<repo>/bin/`) over the handbook source-of-record. Env override `HERMES_SESSION_INIT_FRAGMENT` still takes priority. Handbook copy remains source-of-record.

### Notes

- This is alpha. The mechanism is fully tested. The empirical claim — that injection improves convention-recall in a fresh session — is the subject of E1 and is reported unredacted whether positive or null.
