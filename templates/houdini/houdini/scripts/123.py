"""Start the hrpyc RPC bridge the `houdini` MCP server connects to.

Houdini executes `123.py` from every directory on HOUDINI_PATH at startup, and
this project puts `./houdini` on HOUDINI_PATH (see `projectEnv` in flake.nix),
so this file is what makes the MCP tools connect with nothing pasted into the
Python Shell by hand.

Why this is not just `hrpyc.start_server(port=18811)`
----------------------------------------------------
That one-liner has three problems, all of which this file avoids:

1. **It binds every interface.** The bundled `start_server` builds a
   `ThreadedServer` with no host, so the listening socket goes on `0.0.0.0`.
   RPyC hands the caller a Python interpreter on the far side — it is remote
   code execution by design — so that would put an open RCE port on the
   network. This binds `127.0.0.1`: the MCP server talks to localhost, which is
   all it ever needs.

2. **It cannot report a bind failure.** `use_thread=True` spawns the thread
   and returns it immediately; a busy port raises inside that thread and dies
   there, leaving the caller holding a thread object and no error. Here the
   port is probed first, in this thread, so "something is already listening"
   is a line in the console instead of a silently dead bridge.

3. **It does not return**, see `_start` below — which matters because Houdini
   sources this file on its main thread.

GUI only
--------
`hython` and batch cooks are left alone, so `nix run .#hython -- scripts/x.py`
does not squat the port while it works.

They are told apart by the interpreter binary, not by argv: Houdini's launcher
rewrites argv, so inside `hython script.py` `sys.argv` is `['script.py']` —
indistinguishable from a GUI session. `sys.executable` is not rewritten:
`hython-bin` versus `houdini-bin`.

The script then waits briefly for `hou.isUIAvailable()` before binding, so the
port does not open during startup, and starts anyway once that wait is over.

Reading the log
---------------
Everything is logged to HOUDINI_MCP_LOG from the first line, including the
decision to do nothing and why. Houdini's stdout/stderr go to
`/tmp/UniversalLogStdStream-<pid>-*`, which the launcher deletes, and project
scripts are opened without updating atime — so this file is the only evidence
of what happened at startup:

Environment
    HOUDINI_MCP_PORT  port to listen on (default 18811, what
                      .opencode/opencode.json and the flake's MCP app expect)
    HOUDINI_MCP_RPC   set to 0/off/false to leave the bridge off
    HOUDINI_MCP_LOG   status log (default /tmp/houdini-mcp-bridge.log)

    tail -f /tmp/houdini-mcp-bridge.log

If this is not picked up — a Houdini started outside the project, so without
this HOUDINI_PATH — start the bridge by hand from Help > Python Shell:

    import hrpyc; hrpyc.start_server(port=18811)
"""

import os
import socket
import sys
import threading
import time
from typing import Optional

try:
    import hou
except ImportError:  # pragma: no cover - only when run outside Houdini
    hou = None  # type: ignore[assignment]

HOST = "127.0.0.1"
"""Loopback only. RPyC is remote code execution; do not widen this."""

DEFAULT_PORT = 18811
UI_TIMEOUT = 20.0
"""How long to wait for the interface before starting anyway."""

START_ATTEMPTS = 3
RETRY_SECONDS = 1.0
LOG_PATH = os.environ.get(
    "HOUDINI_MCP_LOG", os.path.join("/tmp", "houdini-mcp-bridge.log")
)


def _log(message: str) -> None:
    """Print to the Python Shell *and* keep a copy.

    Houdini's stdout/stderr go to `/tmp/UniversalLogStdStream-<pid>-*`, which
    the launcher deletes, so a startup failure is otherwise unreadable from
    outside the application.
    """
    line = f"[houdini] mcp bridge: {message}"
    print(line)
    try:
        with open(LOG_PATH, "a", encoding="utf-8") as handle:
            handle.write(f"{time.strftime('%H:%M:%S')} {line}\n")
    except OSError:
        pass  # a log that cannot be written must not break startup


_REPORTED = set()


def _log_once(key: str, message: str) -> None:
    """Log a message the first time only.

    Both startup hooks (123.py and 456.py) run in one session, so "already in
    use" is normal and should not repeat on every scene load.
    """
    if key not in _REPORTED:
        _REPORTED.add(key)
        _log(message)


def _port() -> int:
    try:
        return int(os.environ.get("HOUDINI_MCP_PORT", DEFAULT_PORT))
    except ValueError:
        return DEFAULT_PORT


def _enabled() -> bool:
    return os.environ.get("HOUDINI_MCP_RPC", "1").strip().lower() not in (
        "0",
        "off",
        "false",
        "no",
    )


def _is_hython() -> bool:
    """True under hython, whatever the script name.

    The only reliable signal. `sys.executable` is `.../bin/hython-bin` under
    hython and plain `python3` inside the Houdini GUI (the `houdini-bin` name
    is the OS binary, not what its interpreter reports).

    sys.argv cannot be used for anything: Houdini rewrites it. It is
    `['-c', '-m', 'houdiniInterpreter']` under `hython -c`, `['script.py']`
    under `hython script.py`, and empty in the GUI's Python Shell. A gate keyed
    on it passes a real GUI launch and fails a real hython one.
    """
    return os.path.basename(sys.executable or "").startswith("hython")


def _wait_for_ui(timeout: float = UI_TIMEOUT) -> bool:
    """Block until the interface is up. False if it never arrives."""
    if hou is None:
        return False
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            if hou.isUIAvailable():
                return True
        except Exception:  # noqa: BLE001 - a HOM error must not skip the bridge
            return False
        time.sleep(0.5)
    return False


def _probe(port: int) -> Optional[str]:
    """Check the port is free, returning a reason string if it is not.

    SO_REUSEADDR for the same reason the server sets it: a port left in
    TIME_WAIT by the previous session must not read as "busy". It does not
    weaken the check — without SO_REUSEPORT (never set here) a second live
    listener still gets EADDRINUSE.
    """
    probe = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        probe.bind((HOST, port))
    except OSError as error:
        return f"{HOST}:{port} is already in use ({error})"
    finally:
        probe.close()
    return None


def _start(port: int) -> None:
    """Bind loopback and serve RPyC. Returns once the port answers."""
    # rpyc ships inside Houdini's own site-packages with no stubs, and that
    # directory is not one of the pyright extraPaths (.hou-libs / .hou-site),
    # so these two resolve at runtime only.
    from rpyc.core.service import SlaveService  # type: ignore[import-not-found]
    from rpyc.utils.server import ThreadedServer  # type: ignore[import-not-found]

    server = ThreadedServer(
        SlaveService,
        hostname=HOST,
        port=port,
        # SO_REUSEADDR, so a port still in TIME_WAIT from the previous session
        # can be taken. Not a licence for a second live listener: without
        # SO_REUSEPORT, bind() still fails while one is serving.
        reuse_addr=True,
        auto_register=False,  # no announcement on the RPyC network registry
    )
    server.logger.quiet = True

    # rpyc's Server.start() is *blocking* — it binds, then loops accepting
    # forever in the calling thread. Houdini sources 123.py on its main
    # thread, so calling it here would hang the entire startup. Put it on a
    # daemon thread and wait below for the port to answer instead.
    threading.Thread(
        target=server.start, name="houdini-mcp-bridge", daemon=True
    ).start()

    for _ in range(30):
        time.sleep(0.1)
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as check:
            if check.connect_ex((HOST, port)) == 0:
                return
    raise RuntimeError("the RPyC server thread did not open the port")


def _run(port: int) -> None:
    """Wait for the UI, then get the bridge up, retrying a little."""
    if _wait_for_ui():
        _log("interface is up")
    else:
        _log(f"interface not confirmed within {UI_TIMEOUT:.0f}s — "
             f"starting anyway")

    for attempt in range(START_ATTEMPTS):
        problem = _probe(port)
        if problem is not None:
            if "already in use" in problem:
                # Another Houdini, or a bridge already started this session —
                # either way something is serving, so leave it alone.
                _log_once("in-use", f"{problem} — not starting a second bridge")
            else:
                _log(f"cannot use {problem}")
            return
        try:
            _start(port)
        except Exception as error:  # noqa: BLE001 - never block Houdini startup
            _log(f"attempt {attempt + 1} failed: {error}")
            time.sleep(RETRY_SECONDS)
            continue
        _log(f"listening on {HOST}:{port} — the houdini MCP tools can connect")
        return

    _log(f"gave up after {START_ATTEMPTS} attempts")


def main() -> None:
    # Log first, decide second: this file's output is otherwise unreadable
    # from outside Houdini, so a silent no-op is the worst possible failure.
    _log(f"sourced (exe={os.path.basename(sys.executable or '?')}, "
         f"argv={' '.join(sys.argv) or '<none>'})")

    if not _enabled():
        _log("disabled by HOUDINI_MCP_RPC — not starting")
        return
    if _is_hython():
        _log("running under hython — not starting")
        return

    _log(f"starting on {_port()}")
    # Off the main thread: _run() waits for the interface, which does not
    # exist yet while this file is being sourced.
    threading.Thread(
        target=_run, args=(_port(),), name="houdini-mcp-bridge-start", daemon=True
    ).start()


if __name__ == "__main__":
    main()
else:
    # Houdini sources 123.py as a script, not as __main__.
    main()
