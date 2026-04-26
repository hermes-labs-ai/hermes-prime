# hermes-prime MCP-server scope investigation (read-only)

Date: 2026-04-24

```
EXISTING MCP SCAFFOLDS FOUND:
  - cogito-ergo: ~/.claude/mcp-servers/cogito_mcp.py, 355 LOC, Python (stdlib only), HIGH relevance.
    Hand-rolled JSON-RPC over stdin/stdout. No SDK dependency. Five tools registered
    via a TOOLS list + HANDLERS dict. Implements initialize / tools/list / tools/call /
    ping. Already wired into Claude Code (visible as mcp__cogito-ergo__* in this very session).
  - cogito_dedup.py: same dir, sibling MCP server — confirms the pattern is reused, not one-off.
  - No MCP refs in hermes-handbook or scaffold-corpus. No ai-infra manifest for MCP servers.
  - Other "mcp" hits in projects/ are SDK code in node_modules / claude code internals, not Hermes work.

CLOSEST TEMPLATE:
  ~/.claude/mcp-servers/cogito_mcp.py — pure-stdlib stdio JSON-RPC server, 355 LOC, already
  proven in production (3,500+ memories, live in this session). Strip the HTTP-to-cogito
  client, swap handler bodies for "read CLAUDE-fragment.md from disk," done.

REQUIRED PRIMITIVES FOR HERMES-PRIME-MCP:
  1. One MCP tool: get_conventions(scope_class?: str) -> str
     - Reads CLAUDE-fragment.md (or scope-specific fragment) from a configured path
     - Returns raw markdown content
  2. Optional second tool: list_scopes() -> [str]  (enumerates available fragments)
  3. Standard MCP boilerplate (initialize / tools/list / tools/call) — copy verbatim from cogito_mcp.py
  4. A pyproject.toml entry-point + README install snippet for `claude mcp add`
  5. ~/.claude.json registration line (or instructions for users to add it)
  No auth. No transport choice (stdio is canonical). No state. No HTTP backend.

EFFORT ESTIMATE: 1d
JUSTIFICATION: cogito_mcp.py is a copy-paste-ready template; hermes-prime's tool
surface is strictly smaller (1-2 read-only tools vs 5 with HTTP backend). Real
work is ~80 LOC + tests + README + registration docs. The bash version's logic
(read fragment, return string) is already simpler than cogito's HTTP plumbing.

PIVOT RECOMMENDATION: (b) bash + MCP both
RATIONALE: MCP server is the native Claude Code surface (live, no snapshot, no
file mutation, no CLAUDE.md pollution); bash binary remains the universal-fallback
for non-Claude-Code agents (Cursor, Aider, raw scripts, CI). At 1-day cost the
"both" path dominates "bash-only" — and shipping MCP-only would orphan every
non-Claude-Code consumer hermes-prime currently markets to. Re-evaluate at v0.3
once telemetry shows which surface gets used.

ONE SURPRISING FINDING:
  Cogito's MCP server uses ZERO third-party deps — no `mcp` SDK, no FastMCP, just
  stdlib json + sys. That's the pattern Hermes Labs already battle-tested; don't
  introduce the official SDK for hermes-prime unless we want a runtime dep we
  don't currently carry.
```
