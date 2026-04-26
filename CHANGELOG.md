# Changelog

All notable changes to `hermes-prime` will be documented in this file. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

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
