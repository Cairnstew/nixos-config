#!/usr/bin/env python3
# Minecraft dashboard management API.
#
# Serves per-server status (systemd state, players online, uptime) and
# start/stop/restart actions for the proxy dashboard's Minecraft section.
#
# Endpoints:
#   GET  /status                → [{ name, active, state, players, maxPlayers, uptime, console }]
#   POST /<name>/<action>       → start|stop|restart a server
#
# Runs as the minecraft web console user (cf. my.services.minecraftServer.web.user),
# which holds NOPASSWD sudo for `systemctl {start,stop,restart,status}
# minecraft-server-*`. Player counts are read from the server's latest.log
# (Minecraft logs `There are N of a max of M players online` lines).
import json
import os
import re
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote

DATA_DIR = os.environ.get("MC_DATA_DIR", "/mnt/data/minecraft")
SERVERS = os.environ.get("MC_SERVERS", "").split(":")

SVC = "minecraft-server-{}"
LOG = "{}/{}/logs/latest.log"
PLAYERS_RE = re.compile(r"There are (\d+) of a max of (\d+) players online")

ACTIONS = {"start", "stop", "restart"}


def read_players(name):
    try:
        with open(LOG.format(DATA_DIR, name), "rb") as f:
            # Tail the last 256KB, decode the last match.
            f.seek(0, os.SEEK_END)
            size = f.tell()
            f.seek(max(0, size - 262144))
            data = f.read().decode("utf-8", "replace")
        matches = PLAYERS_RE.findall(data)
        if not matches:
            return None, None
        players, max_players = matches[-1]
        return int(players), int(max_players)
    except Exception:
        return None, None


SYSTEMCTL = "/run/current-system/sw/bin/systemctl"
SUDO = "/run/wrappers/bin/sudo"


def read_uptime(name):
    try:
        out = subprocess.run(
            [SYSTEMCTL, "show", "-p", "ActiveEnterTimestamp", "--value", SVC.format(name)],
            capture_output=True, text=True,
        ).stdout.strip()
        return out or None
    except Exception:
        return None


def run_systemctl(name, action):
    subprocess.run(
        [SUDO, "-n", SYSTEMCTL, action, SVC.format(name)],
        check=True, capture_output=True,
    )


def server_status(name):
    state = subprocess.run(
        [SYSTEMCTL, "is-active", SVC.format(name)],
        capture_output=True, text=True,
    ).stdout.strip()
    active = state == "active"
    players, max_players = read_players(name)
    return {
        "name": name,
        "active": active,
        "state": state,
        "players": players,
        "maxPlayers": max_players,
        "uptime": read_uptime(name) if active else None,
        "console": "/mc/{}/".format(name),
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, code, body, ctype="application/json"):
        if isinstance(body, (dict, list)):
            body = json.dumps(body).encode()
        elif isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.rstrip("/") == "/status":
            self._send(200, [server_status(n) for n in SERVERS])
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self):
        parts = [unquote(p) for p in self.path.strip("/").split("/")]
        if len(parts) != 2:
            self._send(400, {"error": "expected /<name>/<action>"})
            return
        name, action = parts
        if name not in SERVERS:
            self._send(404, {"error": "unknown server {}".format(name)})
            return
        if action not in ACTIONS:
            self._send(400, {"error": "action must be start|stop|restart"})
            return
        try:
            run_systemctl(name, action)
            self._send(200, {"name": name, "action": action, "ok": True})
        except subprocess.CalledProcessError as e:
            self._send(500, {
                "name": name, "action": action, "ok": False,
                "error": e.stderr.decode("utf-8", "replace").strip(),
            })


def main():
    port = int(os.environ.get("MC_API_PORT", "7799"))
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()


if __name__ == "__main__":
    main()
