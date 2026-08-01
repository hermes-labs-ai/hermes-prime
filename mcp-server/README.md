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

## Register in Claude Code

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

Use `claude mcp get hermes-prime` or `claude mcp list` to verify registration.
The tools appear in sessions covered by the selected scope.

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

`HERMES_PRIME_FRAGMENT_ROOT` env var overrides the directory containing
`CLAUDE-fragment.md` (default: repo root, one level up from this file).
Scoped fragments live in `mcp-server/fragments/<scope_class>.md`.

## Tests

```bash
python3 -m pytest mcp-server/test_hermes_prime_mcp.py -v
```

10 tests, stdlib-only (subprocess + json), no `mcp` SDK dependency.
