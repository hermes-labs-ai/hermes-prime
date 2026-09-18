#!/usr/bin/env python3
"""
hermes-prime MCP server for Claude Code.

Exposes session-priming conventions as native MCP tools:
  - get_conventions(scope_class?): return the CLAUDE-fragment markdown
  - list_scopes: enumerate available scoped fragments

Speaks MCP JSON-RPC over stdin/stdout. No third-party deps. Stdlib only.
Pattern matches ~/.claude/mcp-servers/cogito_mcp.py (in-house canon).
"""

from __future__ import annotations

import json
import os
import sys
from importlib import resources
from pathlib import Path

# ── Fragment resolution ──────────────────────────────────────────────────────

# In a checkout the root fragment is canonical. Installed wheels instead use
# the read-only copies bundled in hermes_prime_assets. Keeping the checkout
# path first preserves the Bash and MCP surfaces' shared source artifact.
_DEFAULT_REPO_ROOT = Path(__file__).resolve().parent.parent
_SOURCE_SCOPED_DIR = Path(__file__).resolve().parent / "fragments"
_BUNDLED_ASSET_ROOT = Path(str(resources.files("hermes_prime_assets")))

DEFAULT_FRAGMENT_ROOT = (
    _DEFAULT_REPO_ROOT
    if (_DEFAULT_REPO_ROOT / "CLAUDE-fragment.md").is_file()
    else _BUNDLED_ASSET_ROOT
)
FRAGMENT_ROOT = Path(os.environ.get(
    "HERMES_PRIME_FRAGMENT_ROOT", str(DEFAULT_FRAGMENT_ROOT)
)).resolve()

DEFAULT_FRAGMENT = FRAGMENT_ROOT / "CLAUDE-fragment.md"
SCOPED_DIR = _SOURCE_SCOPED_DIR if _SOURCE_SCOPED_DIR.is_dir() else \
    _BUNDLED_ASSET_ROOT / "fragments"

# ── Protocol constants ───────────────────────────────────────────────────────

# The server has no version-specific behavior (tools/list + tools/call only),
# so it echoes any protocol revision it recognizes and otherwise answers with
# the oldest one, letting the host decide whether to continue.
DEFAULT_PROTOCOL_VERSION = "2024-11-05"
SUPPORTED_PROTOCOL_VERSIONS = ("2024-11-05", "2025-03-26", "2025-06-18")

# Returned in the initialize result. MCP hosts such as Claude Code surface
# server instructions to the model, so this is what prompts a fresh session
# to fetch the card; a tool description alone is not read until a tool is
# considered.
SERVER_INSTRUCTIONS = (
    "hermes-prime serves a versioned convention card for recursive or "
    "emergent work. Call get_conventions once at the start of such a session "
    "and read the returned markdown before planning; skip it for short "
    "single-task fixes. The card is advisory text: it does not enforce "
    "anything or call other tools."
)


def _read_fragment(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return f"Error: fragment not found at {path}"
    except Exception as e:  # pragma: no cover - defensive
        return f"Error: {e}"


# ── Tool handlers ────────────────────────────────────────────────────────────

def handle_get_conventions(args: dict) -> str:
    scope_class = args.get("scope_class")
    if scope_class:
        # Sanitize: no path traversal, no slashes.
        safe = scope_class.replace("/", "").replace("\\", "").strip()
        if safe and safe == scope_class:
            scoped = SCOPED_DIR / f"{safe}.md"
            if scoped.is_file():
                return _read_fragment(scoped)
        # Fallback to default for unknown / invalid scope.
    return _read_fragment(DEFAULT_FRAGMENT)


def handle_list_scopes(args: dict) -> str:
    if not SCOPED_DIR.is_dir():
        return "default"
    scopes = sorted(p.stem for p in SCOPED_DIR.glob("*.md"))
    if not scopes:
        return "default"
    return "\n".join(["default"] + scopes)


HANDLERS = {
    "get_conventions": handle_get_conventions,
    "list_scopes": handle_list_scopes,
}

TOOLS = [
    {
        "name": "get_conventions",
        "description": (
            "Return the hermes-prime CLAUDE-fragment as raw markdown — the "
            "session-priming conventions (grounding triggers, tool map, "
            "rules-most-often-forgotten). Optional scope_class returns a "
            "scoped fragment from fragments/<scope_class>.md when present; "
            "otherwise falls back to the default fragment. Call once at "
            "session start to load conventions without polluting CLAUDE.md."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "scope_class": {
                    "type": "string",
                    "description": (
                        "Optional scope class (e.g. 'session-init'). "
                        "Falls back to the default fragment if unknown."
                    ),
                },
            },
        },
    },
    {
        "name": "list_scopes",
        "description": (
            "List available scoped fragments (one per line). "
            "Always includes 'default'."
        ),
        "inputSchema": {"type": "object", "properties": {}},
    },
]

# ── MCP JSON-RPC protocol ────────────────────────────────────────────────────

def read_message() -> dict | None:
    line = sys.stdin.readline()
    if not line:
        return None
    return json.loads(line.strip())


def send_message(msg: dict) -> None:
    sys.stdout.write(json.dumps(msg) + "\n")
    sys.stdout.flush()


def send_result(request_id, result: dict) -> None:
    send_message({"jsonrpc": "2.0", "id": request_id, "result": result})


def send_error(request_id, code: int, message: str) -> None:
    send_message({
        "jsonrpc": "2.0",
        "id": request_id,
        "error": {"code": code, "message": message},
    })


def main() -> None:
    while True:
        msg = read_message()
        if msg is None:
            break

        method = msg.get("method", "")
        request_id = msg.get("id")

        if method == "initialize":
            requested = (msg.get("params") or {}).get("protocolVersion")
            protocol = requested if requested in SUPPORTED_PROTOCOL_VERSIONS \
                else DEFAULT_PROTOCOL_VERSION
            send_result(request_id, {
                "protocolVersion": protocol,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "hermes-prime", "version": "0.2.1-alpha.1"},
                "instructions": SERVER_INSTRUCTIONS,
            })

        elif method == "notifications/initialized":
            pass

        elif method == "tools/list":
            send_result(request_id, {"tools": TOOLS})

        elif method == "tools/call":
            params = msg.get("params", {})
            tool_name = params.get("name", "")
            tool_args = params.get("arguments", {})

            handler = HANDLERS.get(tool_name)
            if not handler:
                send_error(request_id, -32601, f"Unknown tool: {tool_name}")
                continue

            try:
                text = handler(tool_args)
                send_result(request_id, {
                    "content": [{"type": "text", "text": text}],
                })
            except Exception as e:
                send_result(request_id, {
                    "content": [{"type": "text", "text": f"Error: {e}"}],
                    "isError": True,
                })

        elif method == "ping":
            send_result(request_id, {})

        else:
            if request_id is not None:
                send_error(request_id, -32601, f"Method not found: {method}")


if __name__ == "__main__":
    main()
