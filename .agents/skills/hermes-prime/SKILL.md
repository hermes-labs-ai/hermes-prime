---
name: hermes-prime
description: Use when a fresh Claude Code session needs a versioned convention card (grounding triggers, calibration rules, tool map) delivered without re-deriving them mid-session — either read live over a Claude Code MCP server or injected into a project's CLAUDE.md between markers. This one is a genuine MCP server (get_conventions/list_scopes) plus a separate Bash surface.
license: MIT
compatibility: Requires a bash environment (Bash surface) or Python 3 stdlib only (MCP server). No third-party runtime dependencies for either surface.
---

# hermes-prime

hermes-prime delivers a versioned convention card to a fresh Claude Code
session. The MCP surface returns the card over stdio via `get_conventions`;
the Bash surface snapshots the same card into a project's `CLAUDE.md` between
markers. Neither surface calls a model or a network service, and the
mechanism only makes conventions available — it does not prove a model will
follow them.

## Use it for

- Registering the MCP server so a Claude Code session can call
  `get_conventions` for the current project's convention card
- Injecting the convention fragment into a project's `CLAUDE.md` when the
  workflow reads `CLAUDE.md` directly instead of using MCP
- Checking whether the fragment file is present, or removing an injected
  fragment cleanly

## Do not use it for

- Enforcing that a model actually follows the delivered conventions — this
  is a delivery transport, not a policy enforcer
- A live reference that updates automatically — the injected fragment is a
  snapshot; re-run `--inject` to refresh it after the source fragment changes
- Other agent instruction formats — the Bash surface only understands
  `CLAUDE.md`

## Quickstart

Register the MCP server (recommended for Claude Code):

```bash
claude mcp add --scope local hermes-prime -- python3 "$PWD/mcp-server/hermes_prime_mcp.py"
```

Or use the Bash binary against a project's `CLAUDE.md`:

```bash
git clone https://github.com/hermes-labs-ai/hermes-prime.git
cd hermes-prime
ln -s "$PWD/bin/hermes-session-init" /usr/local/bin/hermes-session-init
hermes-session-init --check
hermes-session-init --print
hermes-session-init --inject ~/Documents/projects/some-project
```

## Output shape

- `--check`: exit `0` when the fragment file is present, `1` when missing
- `--print`: prints the CLAUDE-fragment markdown to stdout
- `--inject <project>`: appends the fragment to `<project>/CLAUDE.md` between
  markers, idempotent, backs up the existing file first; exit `0`
- `--uninject <project>`: removes exactly the injected suffix, byte-restoring
  prior content when possible; exit `0` on success, `1` if not found
- MCP: `get_conventions` / `list_scopes` tools return the same fragment text
  over stdio, with no `CLAUDE.md` mutation

## Common gotchas

- The fragment is a snapshot, not a live reference — `--inject` again after
  the source fragment changes to refresh a project's copy.
- `--uninject` is anchored on the `<!-- session-init: BEGIN/END -->` marker;
  an edited block falls back to marker-preserving removal or the latest
  backup.
- Use `--scope user` for MCP registration only if the same server should be
  available across every project, not just the current one.
- This is one of the few genuine MCP servers in the Hermes Labs catalog —
  most sibling tools expose plain CLIs or HTTP, not MCP.

## More

Full docs, MCP server reference, and CLI reference:
https://github.com/hermes-labs-ai/hermes-prime
