"""PXE server — dnsmasq (DHCP+TFTP) and nginx (HTTP) lifecycle management."""

from __future__ import annotations

import os
import signal
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Optional

from jinja2 import Environment, PackageLoader

from .models import PXEServerConfig

env = Environment(loader=PackageLoader("ipxe_installer", "templates"))


class PXEServer:
    """Manages dnsmasq and nginx processes for PXE booting."""

    def __init__(self, config: PXEServerConfig):
        self.config = config
        self.temp_dir = Path(config.temp_dir or tempfile.mkdtemp(prefix="ipxe-installer-"))
        self.config.temp_dir = str(self.temp_dir)
        self.dnsmasq_proc: Optional[subprocess.Popen] = None
        self.nginx_proc: Optional[subprocess.Popen] = None
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

        # Stop system dnsmasq if running
        subprocess.run(
            ["systemctl", "stop", "dnsmasq"],
            capture_output=True,
        )

        self.dnsmasq_proc = subprocess.Popen(
            ["dnsmasq", "-C", str(conf_path), "--no-daemon"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        time.sleep(0.3)

        if self.dnsmasq_proc.poll() is not None:
            raise RuntimeError(
                f"dnsmasq failed to start (exit code {self.dnsmasq_proc.returncode})"
            )

    def start_nginx(self) -> None:
        """Start nginx process."""
        conf_path = self.write_nginx_conf()
        pid_path = self.temp_dir / "nginx.pid"
        error_log = self.temp_dir / "nginx-error.log"

        self.nginx_proc = subprocess.Popen(
            [
                "nginx",
                "-c", str(conf_path),
                "-p", str(self.temp_dir),
                "-g", f"pid {pid_path}; error_log {error_log};",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        time.sleep(0.5)

        if self.nginx_proc.poll() is not None:
            err = error_log.read_text() if error_log.exists() else "unknown"
            raise RuntimeError(f"nginx failed to start: {err}")

    def stop_dnsmasq(self) -> None:
        """Stop dnsmasq process."""
        if self.dnsmasq_proc:
            self.dnsmasq_proc.terminate()
            try:
                self.dnsmasq_proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.dnsmasq_proc.kill()
            self.dnsmasq_proc = None

    def stop_nginx(self) -> None:
        """Stop nginx process."""
        if self.nginx_proc:
            self.nginx_proc.terminate()
            try:
                self.nginx_proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.nginx_proc.kill()
            self.nginx_proc = None

    def cleanup(self) -> None:
        """Clean up processes and temp directory."""
        if self._cleanup_done:
            return
        self._cleanup_done = True
        self.stop_dnsmasq()
        self.stop_nginx()

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
