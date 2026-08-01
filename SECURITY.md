# Security Policy

## Supported Version Scope

This policy describes the unreleased `0.2.1-alpha.1` source candidate and its two
local runtime surfaces. Publication is a separate owner-controlled action; a
source version or local branch is not evidence that a GitHub release exists.

| Version | Support status | Covered surfaces |
|---|---|---|
| `0.2.1-alpha.1` | Current unreleased source candidate | Bash bootstrap and stdio MCP server |
| `0.2.0` and earlier | No security-fix commitment | Historical Bash/MCP behavior |

Support means security reports will be evaluated. It is not a security audit,
certification, sandbox, or guarantee that the convention fragment is safe for
every project.

## Surfaces and Trust Boundaries

### Bash bootstrap

`bin/hermes-session-init` reads the repository fragment and, for `--inject` or
`--uninject`, changes only the selected project's `CLAUDE.md` and timestamped
`CLAUDE.md.bak.*` files. The caller supplies and trusts the project path. The
script does not authenticate callers, contact a network service, read
credentials intentionally, or change global Claude Code configuration.

The fragment path is trusted input. It resolves from
`HERMES_SESSION_INIT_FRAGMENT`, the repository copy, or the documented local
handbook fallback. Injecting a fragment makes its entire contents visible to
workflows that read the target `CLAUDE.md`.

### MCP server

`mcp-server/hermes_prime_mcp.py` is a local stdio JSON-RPC process launched by
an MCP host. It reads the default fragment and bundled scoped fragments, then
returns their text over stdout. It has no authentication, network transport,
credential store, persistent state, or write tool.

The launching process is the trust boundary. It controls stdin, receives
stdout, and may set `HERMES_PRIME_FRAGMENT_ROOT` to another local directory.
Any data in a selected fragment is therefore available to that host and to
whatever model or logs the host uses. Do not put secrets in fragments.

Claude Code registration is outside this server. `--scope local` and
`--scope user` affect where Claude Code loads the command; the server cannot
verify or narrow that host-managed scope. Register it only at the intended
scope and from a trusted repository path.

## Threat Model and Nonclaims

This project delivers a convention card. It does not enforce those conventions
and does not defend against prompt injection, malicious models, host compromise,
untrusted repository content, operating-system attacks, or other processes
that can read the same files and stdio streams.

Known boundaries and failure modes:

- **Untrusted paths and symlinks:** the Bash path checks that the project is a
  directory but does not prevent symlink races or a caller from selecting a
  sensitive directory. Do not run it on attacker-controlled paths or in a
  hostile multi-user workspace.
- **Marker collision:** a pre-existing `<!-- session-init: BEGIN -->` marker is
  treated as already injected. A writer to the target file can suppress a new
  injection or alter a marker block.
- **Fragment tampering:** both surfaces return or inject the fragment bytes
  they resolve locally. Review repository and override-path changes before
  use; neither surface verifies signatures or provenance.
- **Backup disclosure:** Bash injection copies an existing `CLAUDE.md` to a
  timestamped sibling file. Backups can contain sensitive project guidance and
  are not automatically ignored, encrypted, expired, or deleted.
- **MCP caller and input availability:** any process able to launch the server
  and speak on its stdio can call its tools. Malformed JSON terminates the
  process, and the server does not impose a message-size limit. Treat the MCP
  host as trusted and restart the process after malformed input.
- **MCP path and error disclosure:** an override root can expose a different
  local fragment to the host. Missing-file and defensive error responses can
  include local path or exception text in host-visible output.
- **Scope fallback:** an unknown or rejected `scope_class` returns the default
  fragment rather than failing closed. Callers requiring an exact scoped
  fragment must verify the returned content themselves.

## Local and Public Effects

The Bash surface writes local project files and backups. The MCP process reads
local fragment files and writes protocol responses to stdout. Neither surface
pushes Git refs, creates releases, publishes packages, contacts GitHub, or
changes public state. Installing a symlink or registering the MCP command is a
separate local action performed by the user or host.

## Rollback and Recovery

- For a block appended by the Bash tool, run
  `hermes-session-init --uninject <project-dir>`. Exact unedited suffixes are
  removed byte-for-byte; a file created by injection is removed. Edited or
  externally added marker blocks use the documented marker-removal fallback.
- If the marker is absent, `--uninject` restores the newest timestamped backup
  when one exists. Inspect backups before deleting them; the tool does not
  choose retention policy for you.
- For MCP, remove the registration from the same Claude Code scope, stop the
  process, and unset `HERMES_PRIME_FRAGMENT_ROOT` if used. The server stores no
  state that needs migration.
- These local rollback paths do not reverse a public Git push or release. A
  public correction requires a new owner-authorized commit or release; do not
  rewrite published history as an automatic security response.

## Reporting a Vulnerability

Email **roli@hermes-labs.ai** with subject line `[security] hermes-prime`.
Do not open a public GitHub issue for an unpatched vulnerability.

We will acknowledge a report within 72 hours. If it is valid, we will prepare
a correction and credit the reporter unless anonymity is requested. Any push,
tag, release, or other public action remains separately owner-authorized.
