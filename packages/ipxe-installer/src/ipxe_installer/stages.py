"""Stage management — profile discovery, state machine, iPXE script generation."""

from __future__ import annotations

import json
import os
import shutil
from pathlib import Path
from typing import Optional

from jinja2 import Environment, PackageLoader

from .models import Machine, Profile

env = Environment(loader=PackageLoader("ipxe_installer", "templates"))


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
        """Link profile artifacts into the machine directory."""
        machines_dir = self.http_root / self.MACHINES_DIR / mac
        machines_dir.mkdir(parents=True, exist_ok=True)
        profile_dir = self.http_root / self.PROFILES_DIR / profile.name

        artifacts = ["autounattend.xml", "apply-dsc.ps1",
                     "vmlinuz", "initrd", "config.tar.gz"]
        for art in artifacts:
            src = profile_dir / art
            dst = machines_dir / art
            if src.exists():
                shutil.copy2(str(src), str(dst))

    # ── Full setup ──

    def setup_machine(self, mac: str, profile: Profile) -> None:
        """Full PXE setup for a machine with a given profile.

        1. Write boot.ipxe
        2. Link artifacts from profile to machine dir
        3. Write stage scripts
        4. Set initial stage symlink
        """
        self.write_boot_ipxe()
        self.link_artifacts(mac, profile)
        self.write_stage_scripts(mac, profile.stages, profile.name)
        self._set_stage_symlink(mac, profile.stages[0])
