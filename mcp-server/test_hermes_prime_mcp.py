"""
Tests for hermes-prime MCP server. Stdlib-only — no `mcp` SDK.
Spawns the server as a subprocess, speaks JSON-RPC over stdin/stdout.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

SERVER = Path(__file__).resolve().parent / "hermes_prime_mcp.py"
REPO_ROOT = SERVER.parent.parent
DEFAULT_FRAGMENT = REPO_ROOT / "CLAUDE-fragment.md"
SCOPED_DIR = SERVER.parent / "fragments"


def _rpc(messages: list[dict]) -> list[dict]:
    """Send a sequence of JSON-RPC messages to the server, return responses."""
    payload = "\n".join(json.dumps(m) for m in messages) + "\n"
    proc = subprocess.run(
        [sys.executable, str(SERVER)],
        input=payload,
        capture_output=True,
        text=True,
        timeout=10,
    )
    out = []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if line:
            out.append(json.loads(line))
    return out


def test_initialize():
    [resp] = _rpc([{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}}])
    assert resp["id"] == 1
    assert resp["result"]["serverInfo"]["name"] == "hermes-prime"
    assert "protocolVersion" in resp["result"]


def test_ping():
    [resp] = _rpc([{"jsonrpc": "2.0", "id": 2, "method": "ping"}])
    assert resp["id"] == 2
    assert resp["result"] == {}


def test_tools_list():
    [resp] = _rpc([{"jsonrpc": "2.0", "id": 3, "method": "tools/list"}])
    tools = resp["result"]["tools"]
    names = {t["name"] for t in tools}
    assert names == {"get_conventions", "list_scopes"}
    # get_conventions schema accepts optional scope_class
    gc = next(t for t in tools if t["name"] == "get_conventions")
    assert "scope_class" in gc["inputSchema"]["properties"]
    assert "required" not in gc["inputSchema"] or not gc["inputSchema"].get("required")


def test_get_conventions_default():
    [resp] = _rpc([
        {
            "jsonrpc": "2.0",
            "id": 4,
            "method": "tools/call",
            "params": {"name": "get_conventions", "arguments": {}},
        }
    ])
    text = resp["result"]["content"][0]["text"]
    expected = DEFAULT_FRAGMENT.read_text(encoding="utf-8")
    assert text == expected
    assert "session-init" in text  # sanity check on fragment content


def test_get_conventions_with_scope():
    [resp] = _rpc([
        {
            "jsonrpc": "2.0",
            "id": 5,
            "method": "tools/call",
            "params": {
                "name": "get_conventions",
                "arguments": {"scope_class": "session-init"},
            },
        }
    ])
    text = resp["result"]["content"][0]["text"]
    scoped = (SCOPED_DIR / "session-init.md").read_text(encoding="utf-8")
    assert text == scoped


def test_get_conventions_unknown_scope_falls_back():
    [resp] = _rpc([
        {
            "jsonrpc": "2.0",
            "id": 6,
            "method": "tools/call",
            "params": {
                "name": "get_conventions",
                "arguments": {"scope_class": "nonexistent-scope-xyz"},
            },
        }
    ])
    text = resp["result"]["content"][0]["text"]
    expected = DEFAULT_FRAGMENT.read_text(encoding="utf-8")
    assert text == expected


def test_get_conventions_path_traversal_rejected():
    [resp] = _rpc([
        {
            "jsonrpc": "2.0",
            "id": 7,
            "method": "tools/call",
            "params": {
                "name": "get_conventions",
                "arguments": {"scope_class": "../README"},
            },
        }
    ])
    text = resp["result"]["content"][0]["text"]
    # Should fall back to default, not return README content
    expected = DEFAULT_FRAGMENT.read_text(encoding="utf-8")
    assert text == expected


def test_list_scopes():
    [resp] = _rpc([
        {
            "jsonrpc": "2.0",
            "id": 8,
            "method": "tools/call",
            "params": {"name": "list_scopes", "arguments": {}},
        }
    ])
    text = resp["result"]["content"][0]["text"]
    scopes = text.splitlines()
    assert "default" in scopes
    assert "session-init" in scopes


def test_unknown_tool_errors():
    [resp] = _rpc([
        {
            "jsonrpc": "2.0",
            "id": 9,
            "method": "tools/call",
            "params": {"name": "no_such_tool", "arguments": {}},
        }
    ])
    assert "error" in resp
    assert resp["error"]["code"] == -32601


def test_full_handshake_flow():
    """initialize → notifications/initialized → tools/list → tools/call."""
    responses = _rpc([
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}},
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
        {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {"name": "get_conventions", "arguments": {}},
        },
    ])
    # 3 responses (the notification has no response)
    assert len(responses) == 3
    assert responses[0]["id"] == 1
    assert responses[1]["id"] == 2
    assert responses[2]["id"] == 3
    assert "session-init" in responses[2]["result"]["content"][0]["text"]


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
