# hermes-prime MCP server

Native Claude Code surface for `hermes-prime`. Exposes the session-priming
conventions as MCP tools so a fresh session can call `get_conventions` once
at the top instead of relying on `CLAUDE.md` injection.

Pure stdlib. No third-party deps. ~150 LOC.

## Tools

- `get_conventions(scope_class?)` — returns the CLAUDE-fragment as raw markdown.
  Optional `scope_class` returns `fragments/<scope_class>.md` if it exists,
  else falls back to the default fragment.
- `list_scopes` — enumerates available scoped fragments.

## Register in Claude Code

Recommended (CLI):

```bash
claude mcp add hermes-prime -- python3 /Users/rbr_lpci/Documents/projects/hermes-prime/mcp-server/hermes_prime_mcp.py
```

Manual fallback — add this to `~/.claude.json` under `mcpServers`:

```json
"hermes-prime": {
  "command": "python3",
  "args": ["/Users/rbr_lpci/Documents/projects/hermes-prime/mcp-server/hermes_prime_mcp.py"]
}
```

Restart Claude Code. The tools appear as `mcp__hermes-prime__get_conventions`
and `mcp__hermes-prime__list_scopes`.

## Verify it works

```bash
printf '%s\n%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_conventions","arguments":{}}}' \
  | python3 /Users/rbr_lpci/Documents/projects/hermes-prime/mcp-server/hermes_prime_mcp.py
```

Two JSON-RPC responses; second one contains the fragment markdown.

## Uninstall

```bash
claude mcp remove hermes-prime
```

Or delete the `hermes-prime` entry from `~/.claude.json` `mcpServers`.

## Configuration

`HERMES_PRIME_FRAGMENT_ROOT` env var overrides the directory containing
`CLAUDE-fragment.md` (default: repo root, one level up from this file).
Scoped fragments live in `mcp-server/fragments/<scope_class>.md`.

## Tests

```bash
cd /Users/rbr_lpci/Documents/projects/hermes-prime
python3 -m pytest mcp-server/test_hermes_prime_mcp.py -v
```

10 tests, stdlib-only (subprocess + json), no `mcp` SDK dependency.
