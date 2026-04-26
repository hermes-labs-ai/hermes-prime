# Contributing to hermes-prime

Thanks for looking. Tiny tool, narrow scope — here's how to help without breaking it.

## Scope

This project is a bash bootstrap (~120 LOC) plus a markdown fragment. It primes a fresh Claude Code session with the Hermes Labs conventions. That's it.

Accepted:

- Bug fixes in `bin/hermes-session-init` (POSIX-compliance issues, edge cases in `--inject`/`--uninject`).
- New eval cases in `evals/` — especially recall-test prompts that probe different conventions.
- Documentation corrections.
- CI improvements.
- Honest empirical results (run E1 on your own setup, file an issue with numbers).

Not accepted:

- New runtime dependencies. Bash + coreutils only is part of the tool's shape.
- A Python rewrite. The bash version is the spec.
- A "global mode" that writes into `~/CLAUDE.md`. That's a different problem and the open-design-questions section in `SPEC.md` flags why.
- Auto-call-on-emergence — auto-calling `hermes-ground` from a hook can fire on false positives and burn user trust. Stays out of scope until a clear false-positive rate target is set.

## Dev setup

```bash
git clone https://github.com/hermes-labs-ai/hermes-prime
cd hermes-prime
bash test-bootstrap.sh          # 9 assertions, must all pass
bash evals/preliminary-bootstrap-eval.sh  # 3 evals
```

If `shellcheck` is installed: `shellcheck bin/hermes-session-init`.

## Adding a fragment-content change

The fragment in `CLAUDE-fragment.md` is the *contract*. Changes must:

- Preserve the marker comments `<!-- session-init: BEGIN -->` and `<!-- session-init: END -->` exactly.
- Stay under ~50 lines (the token cost is paid every session that injects).
- Not introduce a tool reference without the tool actually being installable.
- Ship with an updated E1 recall-test case if the convention list changes.

## Reporting a bug

Open an issue with:

- OS + bash version (`bash --version`).
- Subcommand used.
- Project layout (especially: pre-existing `CLAUDE.md`? backup files present?).
- Expected vs actual behavior.
- Output of `hermes-session-init --check`.

## Reporting empirical eval data

If you run the E1 recall test on your own setup, file an issue with:

- claude-cli version.
- Number of trials per condition.
- Recall rates (with-bootstrap vs without-bootstrap), per question.
- Raw transcripts attached.

This is what we need most. Null results published unredacted.

## License

By contributing, you agree your contributions are licensed under the project's MIT License.
