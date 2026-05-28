"""Stage management — profile discovery, state machine, iPXE script generation."""

from __future__ import annotations

import json
import os
import shutil
import socket
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Optional

import yaml
from jinja2 import Environment, PackageLoader

from .autounattend import render_apply_dsc_ps1, render_autounattend
from .models import DSCConfig, Machine, Profile, WindowsUnattendedConfig

env = Environment(loader=PackageLoader("ipxe_installer", "templates"))

_NIXOS_BIN = "/run/current-system/sw/bin"
_LEASE_FILE = "/var/lib/misc/dnsmasq.leases"


def _find_binary(name: str) -> str:
    """Locate a binary, checking NixOS paths before falling back to PATH."""
    nixos_path = Path(_NIXOS_BIN) / name
    if nixos_path.exists():
        return str(nixos_path)
    found = shutil.which(name)
    if found:
        return found
    raise FileNotFoundError(f"{name} not found in PATH")


def _to_nix(value) -> str:
    """Recursively convert a Python value to a Nix expression."""
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        # Use double quotes and escape
        escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return f'"{escaped}"'
    if isinstance(value, list):
        if not value:
            return "[ ]"
        items = "\n".join(f"    {_to_nix(v)}" for v in value)
        return f"[\n{items}\n]"
    if isinstance(value, dict):
        if not value:
            return "{ }"
        items = "\n".join(f"    {k} = {_to_nix(v)};" for k, v in value.items())
        return f"{{\n{items}\n}}"
    return _to_nix(str(value))


class StageManager:
    """Manages install stages for PXE-booted machines."""

    STAGES_DIR = "stages"
    MACHINES_DIR = "machines"
    PROFILES_DIR = "profiles"

    def __init__(self, http_root: str, server_address: str):
        self.http_root = Path(http_root)
        self.server_address = server_address

    # ── Profile discovery ──

    def list_profiles(self) -> list[Profile]:
        """Discover available boot profiles."""
        profiles: list[Profile] = []
        profiles_dir = self.http_root / self.PROFILES_DIR
        if not profiles_dir.exists():
            return profiles

        for pdir in sorted(profiles_dir.iterdir()):
            if not pdir.is_dir():
                continue
            pj = pdir / "profile.json"
            if pj.exists():
                data = json.loads(pj.read_text())
                profiles.append(Profile(name=pdir.name, **data))
            else:
                profiles.append(Profile(name=pdir.name, stages=["done"]))

        return profiles

    def get_profile(self, name: str) -> Optional[Profile]:
        """Get a single profile by name."""
        path = self.http_root / self.PROFILES_DIR / name / "profile.json"
        if path.exists():
            data = json.loads(path.read_text())
            return Profile(name=name, **data)
        return None

    # ── Machine stage state ──

    def get_current_stage(self, mac: str) -> Optional[str]:
        """Read the current stage symlink for a machine."""
        link = self.http_root / f"{mac}.ipxe"
        if not link.is_symlink():
            return None
        target = os.readlink(str(link))
        if "stage-" in target:
            return target.split("stage-")[-1].replace(".ipxe", "")
        return None

    def advance_stage(self, mac: str, stages: list[str], to: Optional[str] = None) -> str:
        """Advance to the next stage (or a specific stage)."""
        current = self.get_current_stage(mac)

        if to:
            if to not in stages:
                raise ValueError(f"Stage '{to}' not in {stages}")
            new_stage = to
        elif current and current in stages:
            idx = stages.index(current)
            if idx + 1 < len(stages):
                new_stage = stages[idx + 1]
            else:
                raise ValueError(f"Already at final stage '{current}'")
        else:
            new_stage = stages[0]

        self._set_stage_symlink(mac, new_stage)
        return new_stage

    def reset_stage(self, mac: str, stages: list[str]) -> str:
        """Reset to the first stage."""
        self._set_stage_symlink(mac, stages[0])
        return stages[0]

    def _set_stage_symlink(self, mac: str, stage: str) -> None:
        """Set the MAC symlink to point to a stage script."""
        link = self.http_root / f"{mac}.ipxe"
        target = f"{self.STAGES_DIR}/{mac}/stage-{stage}.ipxe"
        link.unlink(missing_ok=True)
        link.symlink_to(target)

    # ── Stage script generation ──

    def write_stage_scripts(self, mac: str, stages: list[str], profile_name: str) -> Path:
        """Write iPXE stage scripts for a machine."""
        stages_dir = self.http_root / self.STAGES_DIR / mac
        stages_dir.mkdir(parents=True, exist_ok=True)

        template = env.get_template("stage.ipxe.j2")
        for stage in stages:
            script = template.render(
                stage_name=stage,
                mac=mac,
                server_address=self.server_address,
                profile_name=profile_name,
            )
            (stages_dir / f"stage-{stage}.ipxe").write_text(script)

        return stages_dir

    def write_boot_ipxe(self) -> None:
        """Write the main boot.ipxe dispatcher."""
        template = env.get_template("boot.ipxe.j2")
        content = template.render(
            mac="${mac}",
            server_address=self.server_address,
        )
        (self.http_root / "boot.ipxe").write_text(content)

    # ── Artifact linking ──

    def link_artifacts(self, mac: str, profile: Profile) -> None:
        """Symlink profile artifacts into the machine directory."""
        machines_dir = self.http_root / self.MACHINES_DIR / mac
        machines_dir.mkdir(parents=True, exist_ok=True)
        profile_dir = self.http_root / self.PROFILES_DIR / profile.name

        if not profile_dir.exists():
            return

        artifacts = ["autounattend.xml", "apply-dsc.ps1",
                     "vmlinuz", "initrd", "disko.nix", "configuration.nix"]
        for art in artifacts:
            src = profile_dir / art
            dst = machines_dir / art
            if src.exists():
                dst.unlink(missing_ok=True)
                dst.symlink_to(os.path.relpath(src, dst.parent))

    # ── Full setup ──

    def setup_machine(self, mac: str, profile: Profile) -> None:
        """Full PXE setup for a machine with a given profile.

        1. Write boot.ipxe
        2. Generate missing artifacts in machine dir
        3. Write stage scripts
        4. Set initial stage symlink
        """
        self.write_boot_ipxe()
        self._generate_artifacts(mac, profile)
        self.write_stage_scripts(mac, profile.stages, profile.name)
        self._set_stage_symlink(mac, profile.stages[0])

    # ── nixos-anywhere orchestration ──

    def _target_ip_from_mac(self, mac: str) -> Optional[str]:
        """Find target IP from dnsmasq lease file by MAC address."""
        lease_file = Path(_LEASE_FILE)
        if not lease_file.exists():
            return None
        mac_lower = mac.lower()
        for line in lease_file.read_text().strip().splitlines():
            parts = line.split()
            if len(parts) >= 3 and parts[1].lower() == mac_lower:
                return parts[2]
        return None

    def _wait_for_ssh(self, ip: str, port: int = 22, timeout: int = 300) -> bool:
        """Poll SSH port until open or timeout."""
        start = time.monotonic()
        while time.monotonic() - start < timeout:
            try:
                sock = socket.create_connection((ip, port), timeout=5)
                sock.close()
                return True
            except (OSError, socket.timeout):
                time.sleep(5)
        return False

    def nixos_anywhere(
        self,
        mac: str,
        profile: Profile,
        log_path: Path,
        temp_dir: Optional[Path] = None,
    ) -> bool:
        """Run nixos-anywhere on the target machine.

        1. Find target IP from DHCP leases
        2. Wait for SSH to be ready
        3. Write install configs to temp dir
        4. Run nixos-anywhere, streaming output to log_path
        5. Return True on success, False on failure
        """
        auto = profile.nixos.auto_install
        if not auto.enable:
            return False

        # Find target IP
        ip = self._target_ip_from_mac(mac)
        if not ip:
            with open(log_path, "a") as log:
                log.write(f"[nixos-anywhere] No DHCP lease found for {mac}\n")
            return False

        # Wait for SSH
        with open(log_path, "a") as log:
            log.write(f"[nixos-anywhere] Waiting for root@{ip}:22...\n")
        if not self._wait_for_ssh(ip):
            with open(log_path, "a") as log:
                log.write(f"[nixos-anywhere] SSH timeout for root@{ip}\n")
            return False

        # Prepare config files
        work_dir = temp_dir or Path(tempfile.mkdtemp(prefix="nixos-anywhere-"))
        work_dir.mkdir(parents=True, exist_ok=True)
        disko_file = work_dir / "disko.nix"
        config_file = work_dir / "configuration.nix"

        machines_dir = self.http_root / self.MACHINES_DIR / mac

        src_disko = machines_dir / "disko.nix"
        if src_disko.exists():
            shutil.copy2(str(src_disko), str(disko_file))

        src_config = machines_dir / "configuration.nix"
        if src_config.exists():
            shutil.copy2(str(src_config), str(config_file))
        else:
            shutil.copy2(str(machines_dir / "configuration.nix"), str(config_file))

        if not disko_file.exists() and not config_file.exists():
            with open(log_path, "a") as log:
                log.write("[nixos-anywhere] No disko.nix or configuration.nix found\n")
            return False

        # Build nixos-anywhere command
        cmd = [_find_binary("nixos-anywhere")]
        if disko_file.exists():
            cmd.extend(["--disko", str(disko_file)])
        if config_file.exists():
            cmd.extend(["--configuration", str(config_file)])
        cmd.extend(["--build-on-remote", "--ssh-pass", "nixos123", f"root@{ip}"])

        # Run nixos-anywhere
        with open(log_path, "a") as log:
            log.write(f"[nixos-anywhere] Running: {' '.join(cmd)}\n")

        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )

        # Stream output to log file
        with open(log_path, "a") as log:
            if proc.stdout:
                for line in proc.stdout:
                    decoded = line.decode(errors="replace").rstrip()
                    log.write(decoded + "\n")
                    log.flush()

        rc = proc.wait()
        with open(log_path, "a") as log:
            status = "succeeded" if rc == 0 else f"failed (exit {rc})"
            log.write(f"[nixos-anywhere] {status}\n")

        return rc == 0

    def _generate_artifacts(self, mac: str, profile: Profile) -> None:
        """Generate artifacts at runtime if profile artifacts don't exist."""
        machines_dir = self.http_root / self.MACHINES_DIR / mac
        machines_dir.mkdir(parents=True, exist_ok=True)

        win = profile.windows.unattended
        if win.enable and not (machines_dir / "autounattend.xml").exists():
            xml = render_autounattend(
                WindowsUnattendedConfig(
                    enable=True,
                    partition_index=win.partition_index,
                    local_user=win.local_user,
                    password=win.password,
                    timezone=win.timezone,
                    edition=win.edition,
                    computer_name=win.computer_name,
                    disable_recovery=win.disable_recovery,
                ),
                DSCConfig(
                    registry=profile.dsc_config.registry,
                    features=profile.dsc_config.features,
                ),
                dsc_download_url=f"http://{self.server_address}/machines/{mac}/apply-dsc.ps1",
            )
            (machines_dir / "autounattend.xml").write_text(xml)

        if profile.dsc_config.registry or profile.dsc_config.features:
            if not (machines_dir / "apply-dsc.ps1").exists():
                ps1 = render_apply_dsc_ps1(profile.dsc_config)
                (machines_dir / "apply-dsc.ps1").write_text(ps1)

        # Write NixOS install configs for nixos-anywhere
        auto = profile.nixos.auto_install
        if auto.enable:
            disko_path = machines_dir / "disko.nix"
            if auto.disko_config and not disko_path.exists():
                disko_path.write_text(_to_nix(auto.disko_config))

            config_path = machines_dir / "configuration.nix"
            if auto.nixos_config and not config_path.exists():
                src = Path(auto.nixos_config)
                if src.exists():
                    if config_path.is_symlink() or not config_path.exists():
                        config_path.unlink(missing_ok=True)
                        config_path.symlink_to(os.path.relpath(src, config_path.parent))
