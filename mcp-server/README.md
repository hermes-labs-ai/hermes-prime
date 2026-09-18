# hermes-prime MCP server

Native Claude Code surface for `hermes-prime`. Exposes the session-priming
conventions as MCP tools so a fresh session can call `get_conventions` once
at the top instead of relying on `CLAUDE.md` injection.

Pure stdlib. No third-party runtime dependencies.

## Tools

- `get_conventions(scope_class?)` — returns the CLAUDE-fragment as raw markdown.
  Optional `scope_class` returns `fragments/<scope_class>.md` if it exists,
  else falls back to the default fragment.
- `list_scopes` — enumerates available scoped fragments.

## Install from PyPI (packaged console script)

Once published (see [Packaging status](#packaging-status) below), the server
installs as a standalone console script with no repo checkout required:

```bash
pip install hermes-prime-mcp
hermes-prime-mcp   # speaks MCP JSON-RPC over stdio
```

or run it without installing, via `uvx`:

```bash
uvx --from hermes-prime-mcp hermes-prime-mcp
```

Register the installed script directly with Claude Code:

```bash
claude mcp add --scope local hermes-prime -- hermes-prime-mcp
```

The packaged server reads the versioned convention card bundled in its wheel.
Set `HERMES_PRIME_FRAGMENT_ROOT=/path/to/your/project` only when you want it
to read a trusted custom `CLAUDE-fragment.md` instead (see
[Configuration](#configuration)).

## Register in Claude Code (from a repo checkout)

Run from the repository root. Local scope loads the command for your sessions
in the current project:

```bash
claude mcp add --scope local hermes-prime -- python3 "$PWD/mcp-server/hermes_prime_mcp.py"
```

For a private command available to your sessions across projects, use user
scope:

```bash
claude mcp add --scope user hermes-prime -- python3 "$PWD/mcp-server/hermes_prime_mcp.py"
```

Use `claude mcp get hermes-prime` or `claude mcp list` to verify registration;
both should report the server as Connected (verified with Claude Code 2.1.268
on 2026-09-11). The tools appear in sessions covered by the selected scope,
and the server's `initialize` instructions tell the session to call
`get_conventions` once before recursive or emergent work.

## Verify it works

```bash
printf '%s\n%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_conventions","arguments":{}}}' \
  | python3 "$PWD/mcp-server/hermes_prime_mcp.py"
```

Two JSON-RPC responses; second one contains the fragment markdown.

## Uninstall

```bash
claude mcp remove hermes-prime
```

Remove it from the same project/scope in which it was registered.

## Configuration

`HERMES_PRIME_FRAGMENT_ROOT` overrides the directory containing the default
`CLAUDE-fragment.md`. In a repository checkout the default is the repository
root; in a packaged install it is the immutable card bundled with the wheel.
Scoped fragments are bundled at
`mcp-server/fragments/<scope_class>.md` in a checkout.

## Tests

```bash
python3 -m pytest mcp-server/test_hermes_prime_mcp.py -v
```

13 tests, stdlib-only (subprocess + json), no `mcp` SDK dependency.

## Packaging status

- `pyproject.toml` (repo root) builds an sdist/wheel named `hermes-prime-mcp`
  exposing the `hermes-prime-mcp` console script via `python -m build`.
- `server.json` (repo root) is the MCP Registry manifest, matching the
  registry's `2025-12-11` `server.schema.json`.
- Before publishing, run `mcp-publisher validate server.json`; this verifies
  the live Registry contract without creating a listing.
- **Not yet done by this change, remains for the repo owner:** `twine upload`
  to PyPI, a tagged GitHub release, and `mcp-publisher publish` (or the
  registry's GitHub Action) to submit `server.json`. This branch does not
  create a PyPI credential, a git tag, or a GitHub Release.
