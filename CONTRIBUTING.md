# Contributing to hermes-prime

Thanks for looking. Tiny tool, narrow scope — here's how to help without breaking it.

## Scope

This project is a bash bootstrap plus a markdown fragment, with a stdlib-Python MCP server that serves the same fragment over stdio. It delivers the Hermes Labs convention card to a fresh Claude Code session. That's it.

Accepted:

- Bug fixes in `bin/hermes-session-init` (POSIX-compliance issues, edge cases in `--inject`/`--uninject`) and in `mcp-server/hermes_prime_mcp.py` (protocol handling, fragment resolution).
- New eval cases in `evals/` — especially recall-test prompts that probe different conventions.
- Documentation corrections.
- CI improvements.
- Honest empirical results (run E1 on your own setup, file an issue with numbers).

Not accepted:

- New runtime dependencies. The Bash surface is bash + coreutils only; the MCP server is Python stdlib only (no `mcp` SDK).
- A rewrite of the Bash bootstrap in another language. The bash version is the spec for `CLAUDE.md` injection; the MCP server is a separate read-only surface, not a replacement.
- A "global mode" that writes into `~/CLAUDE.md`. That's a different problem and the open-design-questions section in `SPEC.md` flags why.
- Auto-call-on-emergence — auto-calling `hermes-ground` from a hook can fire on false positives and burn user trust. Stays out of scope until a clear false-positive rate target is set.

## Dev setup

```bash
git clone https://github.com/hermes-labs-ai/hermes-prime
cd hermes-prime
./scripts/local-ci.sh           # shellcheck + 11 Bash assertions + 13 MCP tests + fragment checks
bash evals/preliminary-bootstrap-eval.sh --skip-e1  # E2/E3 mechanism evals (E1 needs claude-cli)
```

The MCP suite alone: `python3 -m pytest mcp-server/test_hermes_prime_mcp.py -q` (needs `pytest`, nothing else).

## Adding a fragment-content change

The fragment in `CLAUDE-fragment.md` is the *contract*. Changes must:

- Preserve the marker comments `<!-- session-init: BEGIN -->` and `<!-- session-init: END -->` exactly.
- Stay within the 8000-character budget enforced by `scripts/local-ci.sh` (the token cost is paid every session that injects).
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
