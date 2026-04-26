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
from pathlib import Path

# ── Fragment resolution ──────────────────────────────────────────────────────

# Configurable via env var; default = repo-root CLAUDE-fragment.md (one level up).
_DEFAULT_REPO_ROOT = Path(__file__).resolve().parent.parent
FRAGMENT_ROOT = Path(
    os.environ.get("HERMES_PRIME_FRAGMENT_ROOT", str(_DEFAULT_REPO_ROOT))
).resolve()

DEFAULT_FRAGMENT = FRAGMENT_ROOT / "CLAUDE-fragment.md"
SCOPED_DIR = Path(__file__).resolve().parent / "fragments"


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
            send_result(request_id, {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "hermes-prime", "version": "0.2.0"},
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
