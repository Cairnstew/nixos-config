#!/usr/bin/env python3
"""MCP protocol adapter: Content-Length framing <-> raw JSON lines.

Wraps mcp-server-git (MCP Python SDK 1.x line-based protocol) so it works
with clients expecting the standard Content-Length header format.

Root cause: MCP SDK 1.x reads raw JSON lines from stdin, while OpenCode uses
the standard Content-Length header format. With raise_exceptions=True, parse
errors from header lines crash the server, causing "Connection closed".
"""

import os
import subprocess
import sys
import threading


def main() -> None:
    args = sys.argv[1:]

    repo_path = None
    i = 0
    while i < len(args):
        if args[i] in ("--repository", "-r") and i + 1 < len(args):
            repo_path = args[i + 1]
            i += 2
        else:
            i += 1

    if repo_path is None:
        repo_path = os.getcwd()

    child = subprocess.Popen(
        ["uvx", "mcp-server-git", "--repository", repo_path],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    def forward_stderr() -> None:
        for line in child.stderr:
            sys.stderr.buffer.write(line)
        sys.stderr.buffer.flush()

    t = threading.Thread(target=forward_stderr, daemon=True)
    t.start()

    # MCP is request-response: read one request, forward, read response, repeat
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            break

        body: bytes | None = None

        if line.startswith(b"Content-Length:"):
            length = int(line.split(b":")[1].strip())
            sys.stdin.buffer.readline()  # consume blank line
            body = sys.stdin.buffer.read(length)
        elif line.strip():
            body = line

        if body is None:
            continue

        child.stdin.write(body + b"\n")
        child.stdin.flush()

        resp = child.stdout.readline()
        if not resp:
            break

        resp = resp.rstrip(b"\n").rstrip(b"\r")
        byte_len = len(resp)

        sys.stdout.buffer.write(f"Content-Length: {byte_len}\r\n\r\n".encode())
        sys.stdout.buffer.write(resp)
        sys.stdout.buffer.flush()

    child.stdin.close()
    child.wait()


if __name__ == "__main__":
    main()
