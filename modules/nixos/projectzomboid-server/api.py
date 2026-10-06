#!/usr/bin/env python3
# Project Zomboid dashboard management API.
#
# Serves per-server status and start/stop/restart actions for the proxy
# dashboard's Project Zomboid section (my.services.proxy.dashboard.projectzomboid).
#
# Endpoints:
#   GET  /status           -> [{ name, active, state, since, memory, console }]
#   POST /<name>/<action>  -> start|stop|restart a server
#
# Runs as the Project Zomboid web-console user (cf. the upstream module's
# `web.user`). No sudo anywhere: the upstream module grants that user a polkit
# rule for `org.freedesktop.systemd1.manage-units` on `project-zomboid-*`, which
# systemctl consults over D-Bus automatically. Both reads and the acting verbs
# therefore run unprivileged — `is-active`/`show` are readable by every user,
# and start/stop/restart are authorised by polkit.
#
# This matters on hosts that set `security.sudo.execWheelOnly = true`: a scoped
# sudoers rule would be unreachable there (the sudo wrapper itself is wheel-only),
# so `sudo -n` would fail and every card would read `unknown`.
#
# Deliberately NO player count. Project Zomboid's dedicated server writes no
# machine-readable player list: there is no console.txt and no logs/ directory
# until a session exists, and join/leave lines are free-text. A real count means
# RCON (`rconPort` + the RCONPassword secret), which is a follow-up rather than
# something to fake here — the console link is the honest answer for "who is on".
import json
import os
import subprocess
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote

# Unit names are `project-zomboid-<name>`; see the upstream module's `unitName`.
UNIT = "project-zomboid-{}"
SERVERS = [s for s in os.environ.get("PZ_SERVERS", "").split(":") if s]
CONSOLE_BASE = os.environ.get("PZ_CONSOLE_BASE", "/pz")
ACTIONS = {"start", "stop", "restart"}


def systemctl(*args):
    """Run `systemctl <args>` as the console user.

    No sudo: reads are world-readable over D-Bus, and the acting verbs are
    authorised by the polkit rule the upstream module installs.
    """
    p = subprocess.run(
        ["systemctl", *args], capture_output=True, text=True, timeout=15
    )
    return p.returncode, p.stdout.strip()


def show(unit, prop):
    rc, out = systemctl("show", unit, "-p", prop, "--value")
    return out if rc == 0 else ""


def uptime_seconds(unit):
    """Seconds since the unit entered `active`, from the monotonic timestamp.

    ActiveEnterTimestampMonotonic is microseconds since boot, so it is combined
    with the current boot time rather than parsed as a date — that avoids
    depending on systemd's locale-formatted ActiveEnterTimestamp.
    """
    raw = show(unit, "ActiveEnterTimestampMonotonic")
    if not raw or raw == "0":
        return None
    try:
        entered_mono = int(raw) / 1_000_000
    except ValueError:
        return None
    with open("/proc/uptime") as fh:
        boot_mono = time.time() - float(fh.read().split()[0])
    return max(0, int(time.time() - (boot_mono + entered_mono)))


def status(name):
    unit = UNIT.format(name)
    rc, state = systemctl("is-active", unit)
    state = state or "unknown"
    active = rc == 0 and state == "active"

    mem = show(unit, "MemoryCurrent")
    try:
        memory = int(mem) if mem and mem != "[not set]" else None
    except ValueError:
        memory = None

    return {
        "name": name,
        "active": active,
        "state": state,
        "uptime": uptime_seconds(unit) if active else None,
        "memory": memory,
        "console": f"{CONSOLE_BASE}/{name}/",
    }


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.split("?")[0].rstrip("/") == "/status":
            self._send(200, [status(n) for n in SERVERS])
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self):
        parts = [unquote(p) for p in self.path.strip("/").split("/") if p]
        if len(parts) != 2 or parts[0] not in SERVERS or parts[1] not in ACTIONS:
            self._send(404, {"error": "expected POST /<server>/(start|stop|restart)"})
            return
        name, action = parts
        # --no-block: the unit is forking with TimeoutStopSec=90s, so `restart`
        # blocks far past any sane HTTP timeout (and a killed client leaves the
        # job running anyway). Queue it and return; the dashboard polls /status
        # for the outcome.
        rc, out = systemctl(action, UNIT.format(name), "--no-block")
        self._send(200 if rc == 0 else 500, {"ok": rc == 0, "output": out})

    def log_message(self, format, *args):
        pass  # keep the journal quiet; systemd already records failures


if __name__ == "__main__":
    port = int(os.environ.get("PZ_API_PORT", "7798"))
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
