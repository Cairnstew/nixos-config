"""Tests for ipxe_installer.stages (StageManager)."""

import json
import os
from pathlib import Path

import pytest
from ipxe_installer.models import Profile
from ipxe_installer.stages import StageManager


@pytest.fixture
def mgr(tmp_path: Path) -> StageManager:
    http_root = tmp_path / "pxe"
    http_root.mkdir()
    return StageManager(str(http_root), "192.168.99.1")


class TestStageManager:
    def test_list_profiles_empty(self, mgr: StageManager):
        assert mgr.list_profiles() == []

    def test_list_profiles_with_data(self, mgr: StageManager):
        pdir = mgr.http_root / mgr.PROFILES_DIR / "dual-boot"
        pdir.mkdir(parents=True)
        (pdir / "profile.json").write_text(json.dumps({
            "description": "Dual boot",
            "stages": ["nixos", "windows", "done"],
        }))
        profiles = mgr.list_profiles()
        assert len(profiles) == 1
        assert profiles[0].name == "dual-boot"
        assert profiles[0].stages == ["nixos", "windows", "done"]

    def test_get_profile_not_found(self, mgr: StageManager):
        assert mgr.get_profile("nonexistent") is None

    def test_get_profile_found(self, mgr: StageManager):
        pdir = mgr.http_root / mgr.PROFILES_DIR / "test"
        pdir.mkdir(parents=True)
        (pdir / "profile.json").write_text(json.dumps({"stages": ["done"]}))
        prof = mgr.get_profile("test")
        assert prof is not None
        assert prof.name == "test"

    def test_get_current_stage_no_link(self, mgr: StageManager):
        assert mgr.get_current_stage("aa:bb:cc:dd:ee:ff") is None

    def test_get_current_stage_with_link(self, mgr: StageManager):
        link = mgr.http_root / "aa:bb:cc:dd:ee:ff.ipxe"
        # Create target file first so symlink is valid
        target_dir = mgr.http_root / "stages" / "aa:bb:cc:dd:ee:ff"
        target_dir.mkdir(parents=True)
        (target_dir / "stage-nixos.ipxe").write_text("#!ipxe")
        target = "stages/aa:bb:cc:dd:ee:ff/stage-nixos.ipxe"
        link.symlink_to(target)
        assert mgr.get_current_stage("aa:bb:cc:dd:ee:ff") == "nixos"

    def test_advance_stage_from_start(self, mgr: StageManager):
        stages = ["nixos", "windows", "done"]
        result = mgr.advance_stage("mac1", stages)
        assert result == "nixos"
        link = mgr.http_root / "mac1.ipxe"
        assert link.is_symlink()
        assert "stage-nixos" in os.readlink(str(link))

    def test_advance_stage_to_specific(self, mgr: StageManager):
        stages = ["nixos", "windows", "done"]
        mgr.advance_stage("mac1", stages)
        result = mgr.advance_stage("mac1", stages, to="windows")
        assert result == "windows"

    def test_advance_stage_sequential(self, mgr: StageManager):
        stages = ["nixos", "windows", "done"]
        mgr.advance_stage("mac1", stages)
        result = mgr.advance_stage("mac1", stages)
        assert result == "windows"

    def test_advance_stage_already_final(self, mgr: StageManager):
        stages = ["done"]
        mgr.advance_stage("mac1", stages)
        with pytest.raises(ValueError, match="Already at final stage"):
            mgr.advance_stage("mac1", stages)

    def test_advance_stage_invalid_target(self, mgr: StageManager):
        stages = ["nixos", "done"]
        with pytest.raises(ValueError, match="not in"):
            mgr.advance_stage("mac1", stages, to="windows")

    def test_reset_stage(self, mgr: StageManager):
        stages = ["nixos", "windows", "done"]
        mgr.advance_stage("mac1", stages)
        mgr.advance_stage("mac1", stages)  # now at windows
        result = mgr.reset_stage("mac1", stages)
        assert result == "nixos"

    def test_write_stage_scripts(self, mgr: StageManager):
        stages_dir = mgr.write_stage_scripts("mac1", ["nixos", "done"], "test")
        assert stages_dir.exists()
        for stage in ["nixos", "done"]:
            f = stages_dir / f"stage-{stage}.ipxe"
            assert f.exists()
            content = f.read_text()
            assert "#!ipxe" in content
            # Template capitalizes stage name
            assert stage.capitalize() in content

    def test_write_boot_ipxe(self, mgr: StageManager):
        mgr.write_boot_ipxe()
        boot = mgr.http_root / "boot.ipxe"
        assert boot.exists()
        assert "NixOS Netboot Server" in boot.read_text()

    def test_link_artifacts(self, mgr: StageManager, tmp_path: Path):
        profile = Profile(name="test", stages=["done"])
        pdir = mgr.http_root / mgr.PROFILES_DIR / "test"
        pdir.mkdir(parents=True)
        (pdir / "vmlinuz").write_text("kernel")
        (pdir / "initrd").write_text("initrd")

        mgr.link_artifacts("mac1", profile)
        mdir = mgr.http_root / mgr.MACHINES_DIR / "mac1"
        assert (mdir / "vmlinuz").exists()
        assert (mdir / "vmlinuz").read_text() == "kernel"

    def test_full_setup(self, mgr: StageManager):
        profile = Profile(name="test", stages=["nixos", "done"])
        pdir = mgr.http_root / mgr.PROFILES_DIR / "test"
        pdir.mkdir(parents=True)
        (pdir / "profile.json").write_text(json.dumps({"stages": ["nixos", "done"]}))
        (pdir / "vmlinuz").write_text("kernel")

        mgr.setup_machine("aa:bb:cc:dd:ee:ff", profile)
        assert (mgr.http_root / "boot.ipxe").exists()
        assert (mgr.http_root / "aa:bb:cc:dd:ee:ff.ipxe").is_symlink()
        assert (mgr.http_root / "machines" / "aa:bb:cc:dd:ee:ff" / "vmlinuz").exists()
        stages_dir = mgr.http_root / "stages" / "aa:bb:cc:dd:ee:ff"
        assert (stages_dir / "stage-nixos.ipxe").exists()
        assert (stages_dir / "stage-done.ipxe").exists()
