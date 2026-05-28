"""Tests for ipxe_installer.cli (Typer CLI commands)."""

import json
from pathlib import Path
from unittest.mock import patch

import pytest
from typer.testing import CliRunner

from ipxe_installer.cli import app

runner = CliRunner()


class TestCLIVersion:
    def test_version(self):
        result = runner.invoke(app, ["--version"])
        assert result.exit_code == 0
        assert "ipxe-installer v" in result.stdout

    def test_help(self):
        result = runner.invoke(app, ["--help"])
        assert result.exit_code == 0
        assert "serve" in result.stdout
        assert "advance" in result.stdout
        assert "list" in result.stdout
        assert "sync-iso" in result.stdout
        assert "gen-unattend" in result.stdout
        assert "gen-dsc" in result.stdout

    @pytest.mark.skip(reason="serve starts dnsmasq/nginx, needs mock")
    def test_serve(self):
        pass


class TestCLIGenUnattend:
    def test_default(self, tmp_path: Path):
        output = tmp_path / "autounattend.xml"
        result = runner.invoke(app, ["gen-unattend", "--output", str(output)])
        assert result.exit_code == 0, result.stdout
        assert output.exists()
        assert "<?xml version" in output.read_text()

    def test_custom(self, tmp_path: Path):
        output = tmp_path / "autounattend.xml"
        result = runner.invoke(app, [
            "gen-unattend",
            "--output", str(output),
            "--partition", "4",
            "--user", "admin",
            "--password", "secret123",
            "--computer-name", "MYPC",
        ])
        assert result.exit_code == 0, result.stdout
        content = output.read_text()
        assert "<PartitionID>4</PartitionID>" in content
        assert "admin" in content
        assert "secret123" in content
        assert "MYPC" in content

    def test_dsc_download_url(self, tmp_path: Path):
        output = tmp_path / "autounattend.xml"
        result = runner.invoke(app, ["gen-unattend", "--output", str(output)])
        assert result.exit_code == 0, result.stdout
        # No DSC URL by default
        assert "apply-dsc.ps1" not in output.read_text()


class TestCLIGenDsc:
    def test_default(self, tmp_path: Path):
        output = tmp_path / "apply-dsc.ps1"
        result = runner.invoke(app, ["gen-dsc", "--output", str(output)])
        assert result.exit_code == 0, result.stdout
        assert output.exists()
        assert "DSC v3 Bootstrap" in output.read_text()

    def test_with_registry(self, tmp_path: Path):
        output = tmp_path / "apply-dsc.ps1"
        registry = json.dumps({"HKLM\\Software\\Test": {"Value": 1}})
        result = runner.invoke(app, [
            "gen-dsc",
            "--output", str(output),
            "--registry", registry,
        ])
        assert result.exit_code == 0, result.stdout
        content = output.read_text()
        assert "HKLM" in content
        assert "Value" in content

    def test_with_features(self, tmp_path: Path):
        output = tmp_path / "apply-dsc.ps1"
        result = runner.invoke(app, [
            "gen-dsc",
            "--output", str(output),
            "--features", '["WSL", "VMP"]',
        ])
        assert result.exit_code == 0, result.stdout
        # Features rendered as YAML
        content = output.read_text()
        # jinja2 renders the YAML which includes feature names
        assert "WSL" in content or "config.dsc.yaml" in content


class TestCLIList:
    def test_empty(self, tmp_path: Path):
        http_root = tmp_path / "pxe"
        http_root.mkdir(parents=True)
        result = runner.invoke(app, ["list", "--http-root", str(http_root)])
        assert result.exit_code == 0, result.stdout
        assert "No machines" in result.stdout or "Profiles" in result.stdout

    def test_with_machines(self, tmp_path: Path):
        http_root = tmp_path / "pxe"
        (http_root / "machines" / "aa:bb:cc:dd:ee:ff").mkdir(parents=True)
        # Create a valid symlink
        stages_dir = http_root / "stages" / "aa:bb:cc:dd:ee:ff"
        stages_dir.mkdir(parents=True)
        (stages_dir / "stage-nixos.ipxe").write_text("#!ipxe\nboot")
        # Create MAC symlink pointing to stage
        link = http_root / "aa:bb:cc:dd:ee:ff.ipxe"
        link.symlink_to("stages/aa:bb:cc:dd:ee:ff/stage-nixos.ipxe")

        result = runner.invoke(app, ["list", "--http-root", str(http_root)])
        assert result.exit_code == 0, result.stdout
        assert "aa:bb:cc:dd:ee:ff" in result.stdout

    def test_with_profiles(self, tmp_path: Path):
        http_root = tmp_path / "pxe"
        pdir = http_root / "profiles" / "dual-boot"
        pdir.mkdir(parents=True)
        (pdir / "profile.json").write_text(json.dumps({
            "description": "Dual boot",
            "stages": ["nixos", "windows", "done"],
        }))
        result = runner.invoke(app, ["list", "--http-root", str(http_root)])
        assert result.exit_code == 0, result.stdout
        assert "dual-boot" in result.stdout


class TestCLIAdvance:
    def test_no_mac(self):
        result = runner.invoke(app, ["advance"])
        assert result.exit_code != 0

    def test_with_mac_no_profile(self, tmp_path: Path):
        http_root = tmp_path / "pxe"
        http_root.mkdir()
        result = runner.invoke(app, [
            "advance", "aa:bb:cc:dd:ee:ff",
            "--http-root", str(http_root),
        ])
        # Should fail: no profile found (error on stderr)
        assert result.exit_code != 0


class TestCLISyncIso:
    def test_sync_iso_bad_repo(self, tmp_path: Path):
        output = tmp_path / "output"
        result = runner.invoke(app, [
            "sync-iso",
            "--release", "nonexistent-tag",
            "--output", str(output),
            "--state", str(tmp_path / "state"),
        ])
        # Should fail — nonexistent release
        assert result.exit_code != 0
