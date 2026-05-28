"""PXE server — dnsmasq (DHCP+TFTP) and nginx (HTTP) lifecycle management."""

from __future__ import annotations

import os
import shutil
import signal
import socket
import subprocess
import tempfile
import threading
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from typing import Optional

from jinja2 import Environment, PackageLoader

from .models import PXEServerConfig

env = Environment(loader=PackageLoader("ipxe_installer", "templates"))

# Common NixOS locations for system binaries
_NIXOS_BIN = "/run/current-system/sw/bin"


def _find_binary(name: str) -> str:
    """Locate a binary, checking NixOS paths before falling back to PATH."""
    nixos_path = Path(_NIXOS_BIN) / name
    if nixos_path.exists():
        return str(nixos_path)
    found = shutil.which(name)
    if found:
        return found
    raise FileNotFoundError(
        f"{name} not found — ensure dnsmasq and nginx are installed "
        f"(broken by nixos-rebuild on NixOS)"
    )


class LogRelay:
    """HTTP server that accepts target machine log uploads via PUT."""

    def __init__(self, store_dir: Path, port: int = 8081):
        self.store_dir = store_dir
        self.port = port
        self._server: Optional[HTTPServer] = None
        self._thread: Optional[threading.Thread] = None

    def start(self):
        store_dir = self.store_dir

        class _Handler(BaseHTTPRequestHandler):
            def do_PUT(self):
                parts = self.path.strip("/").split("/")
                if len(parts) >= 2 and parts[0] == "logs":
                    mac = parts[1]
                    content_length = int(self.headers.get("Content-Length", 0))
                    body = self.rfile.read(content_length) if content_length > 0 else b""
                    log_dir = store_dir / mac
                    log_dir.mkdir(parents=True, exist_ok=True)
                    (log_dir / "installer.log").write_bytes(body)
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"OK")
                else:
                    self.send_response(404)
                    self.end_headers()

            def log_message(self, format, *args):
                pass

        self._server = HTTPServer(("0.0.0.0", self.port), _Handler)
        self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)
        self._thread.start()

    def stop(self):
        if self._server:
            self._server.shutdown()


class NetconsoleListener:
    """UDP listener that captures kernel boot logs via netconsole."""

    def __init__(self, store_dir: Path, port: int = 6666):
        self.store_dir = store_dir
        self.port = port
        self._thread: Optional[threading.Thread] = None
        self._running = False

    def start(self):
        self._running = True
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def _run(self):
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(("0.0.0.0", self.port))
        sock.settimeout(1)
        logs_dir = self.store_dir

        while self._running:
            try:
                data, addr = sock.recvfrom(8192)
                src_ip = addr[0]
                log_dir = logs_dir / src_ip
                log_dir.mkdir(parents=True, exist_ok=True)
                with open(log_dir / "kernel.log", "ab") as f:
                    f.write(data)
                    f.write(b"\n")
            except socket.timeout:
                continue
            except OSError:
                break

    def stop(self):
        self._running = False
        if self._thread:
            self._thread.join(timeout=3)


class PXEServer:
    """Manages dnsmasq and nginx processes for PXE booting."""

    def __init__(self, config: PXEServerConfig):
        self.config = config
        self.temp_dir = Path(config.temp_dir or tempfile.mkdtemp(prefix="ipxe-installer-"))
        self.config.temp_dir = str(self.temp_dir)
        self.dnsmasq_proc: Optional[subprocess.Popen] = None
        self.nginx_proc: Optional[subprocess.Popen] = None
        self.log_relay: Optional[LogRelay] = None
        self.netconsole: Optional[NetconsoleListener] = None
        self._cleanup_done = False

    def ensure_dirs(self) -> None:
        """Create required directories."""
        for d in [self.config.http_root, self.config.tftp_root]:
            Path(d).mkdir(parents=True, exist_ok=True)
        (self.temp_dir / "logs").mkdir(parents=True, exist_ok=True)

    def write_dnsmasq_conf(self) -> Path:
        """Write dnsmasq configuration file."""
        template = env.get_template("dnsmasq.conf.j2")
        conf = template.render(
            interface=self.config.interface,
            server_address=self.config.server_address,
            dhcp_range_start=self.config.dhcp_range_start,
            dhcp_range_end=self.config.dhcp_range_end,
            dhcp_lease_time=self.config.dhcp_lease_time,
            tftp_root=self.config.tftp_root,
        )
        path = self.temp_dir / "dnsmasq.conf"
        path.write_text(conf)
        return path

    def write_nginx_conf(self) -> Path:
        """Write nginx configuration file."""
        template = env.get_template("nginx.conf.j2")
        conf = template.render(
            server_address=self.config.server_address,
            http_root=self.config.http_root,
            temp_dir=str(self.temp_dir),
        )
        path = self.temp_dir / "nginx.conf"
        path.write_text(conf)
        return path

    def start_dnsmasq(self) -> None:
        """Start dnsmasq process."""
        conf_path = self.write_dnsmasq_conf()

        # Kill any existing dnsmasq (orphaned from previous runs)
        subprocess.run(["pkill", "-x", "dnsmasq"], capture_output=True)
        time.sleep(0.3)
        # Also try systemd stop in case it's managed
        subprocess.run(["systemctl", "stop", "dnsmasq"], capture_output=True)

        dnsmasq_bin = _find_binary("dnsmasq")
        self.dnsmasq_proc = subprocess.Popen(
            [dnsmasq_bin, "-C", str(conf_path), "--no-daemon"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        time.sleep(0.3)

        if self.dnsmasq_proc.poll() is not None:
            raise RuntimeError(
                f"dnsmasq failed to start (exit code {self.dnsmasq_proc.returncode})"
            )

    def _ensure_log_dir(self) -> None:
        """Ensure /var/log/nginx exists for nginx's initial error log."""
        log_dir = Path("/var/log/nginx")
        log_dir.mkdir(parents=True, exist_ok=True)

    def start_nginx(self) -> None:
        """Start nginx process."""
        self._ensure_log_dir()
        conf_path = self.write_nginx_conf()
        pid_path = self.temp_dir / "nginx.pid"
        error_log = self.temp_dir / "nginx-error.log"

        # Kill any existing nginx (orphaned from previous runs)
        subprocess.run(["pkill", "-x", "nginx"], capture_output=True)
        time.sleep(0.3)
        # Also try systemd stop in case it's managed
        subprocess.run(["systemctl", "stop", "nginx"], capture_output=True)

        nginx_bin = _find_binary("nginx")
        self.nginx_proc = subprocess.Popen(
            [
                nginx_bin,
                "-c", str(conf_path),
                "-p", str(self.temp_dir),
                "-g", f"pid {pid_path}; error_log {error_log}; daemon off;",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        time.sleep(0.5)

        if self.nginx_proc.poll() is not None:
            stdout, _ = self.nginx_proc.communicate()
            err = stdout.decode() if stdout else ""
            log = error_log.read_text() if error_log.exists() else ""
            detail = log or err or "unknown error (check nginx -t)"
            raise RuntimeError(f"nginx failed to start: {detail.strip()}")

    def stop_dnsmasq(self) -> None:
        """Stop dnsmasq process."""
        if self.dnsmasq_proc:
            self.dnsmasq_proc.terminate()
            try:
                self.dnsmasq_proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.dnsmasq_proc.kill()
            self.dnsmasq_proc = None
        subprocess.run(["pkill", "-x", "dnsmasq"], capture_output=True)

    def stop_nginx(self) -> None:
        """Stop nginx process."""
        if self.nginx_proc:
            self.nginx_proc.terminate()
            try:
                self.nginx_proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.nginx_proc.kill()
            self.nginx_proc = None
        subprocess.run(["pkill", "-x", "nginx"], capture_output=True)

    def start_log_relay(self) -> None:
        """Start HTTP log relay for target machine logs."""
        self.log_relay = LogRelay(self.temp_dir / "logs")
        self.log_relay.start()

    def stop_log_relay(self) -> None:
        """Stop HTTP log relay."""
        if self.log_relay:
            self.log_relay.stop()

    def start_netconsole(self) -> None:
        """Start UDP listener for kernel netconsole messages."""
        self.netconsole = NetconsoleListener(self.temp_dir / "logs")
        self.netconsole.start()

    def stop_netconsole(self) -> None:
        """Stop netconsole UDP listener."""
        if self.netconsole:
            self.netconsole.stop()

    def cleanup(self) -> None:
        """Clean up processes and temp directory."""
        if self._cleanup_done:
            return
        self._cleanup_done = True
        self.stop_dnsmasq()
        self.stop_nginx()
        self.stop_log_relay()
        self.stop_netconsole()

    def __enter__(self) -> "PXEServer":
        self.ensure_dirs()
        return self

    def __exit__(self, *args) -> None:
        self.cleanup()

    def setup_signal_handlers(self) -> None:
        """Set up signal handlers for graceful cleanup."""

        def _handler(signum, frame):
            self.cleanup()
            os._exit(0)

        signal.signal(signal.SIGINT, _handler)
        signal.signal(signal.SIGTERM, _handler)
