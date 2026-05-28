"""Tests for ipxe_installer.server (PXEServer)."""

from pathlib import Path

import pytest
from ipxe_installer.models import PXEServerConfig
from ipxe_installer.server import PXEServer, _find_binary


@pytest.fixture
def config(tmp_path: Path) -> PXEServerConfig:
    return PXEServerConfig(
        interface="eth0",
        server_address="192.168.99.1",
        http_root=str(tmp_path / "pxe"),
        tftp_root=str(tmp_path / "tftp"),
        dhcp_range_start="192.168.99.100",
        dhcp_range_end="192.168.99.200",
        dhcp_lease_time="1d",
    )


class TestFindBinary:
    def test_find_binary_nixos_path(self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path):
        """Should find binary in /run/current-system/sw/bin."""
        fake_bin = tmp_path / "run" / "current-system" / "sw" / "bin"
        fake_bin.mkdir(parents=True)
        (fake_bin / "dnsmasq").write_text("#!/bin/sh\necho fake")
        (fake_bin / "dnsmasq").chmod(0o755)
        monkeypatch.setattr("ipxe_installer.server._NIXOS_BIN", str(fake_bin))
        assert _find_binary("dnsmasq") == str(fake_bin / "dnsmasq")

    def test_find_binary_via_path(self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path):
        """Should fall back to PATH lookup."""
        fake_bin = tmp_path / "bin"
        fake_bin.mkdir()
        (fake_bin / "dnsmasq").write_text("#!/bin/sh\necho fake")
        (fake_bin / "dnsmasq").chmod(0o755)
        monkeypatch.setattr("ipxe_installer.server._NIXOS_BIN", str(tmp_path / "nonexistent-bin"))
        monkeypatch.setenv("PATH", str(fake_bin))
        assert _find_binary("dnsmasq") == str(fake_bin / "dnsmasq")

    def test_find_binary_not_found(self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path):
        """Should raise FileNotFoundError."""
        monkeypatch.setattr("ipxe_installer.server._NIXOS_BIN", str(tmp_path / "nonexistent-bin"))
        monkeypatch.setenv("PATH", str(tmp_path / "nonexistent-path"))
        with pytest.raises(FileNotFoundError, match="not found"):
            _find_binary("this-binary-does-not-exist-xyz")


class TestPXEServer:
    def test_init(self, config: PXEServerConfig):
        server = PXEServer(config)
        assert server.config == config
        assert server.dnsmasq_proc is None
        assert server.nginx_proc is None

    def test_ensure_dirs(self, config: PXEServerConfig):
        server = PXEServer(config)
        server.ensure_dirs()
        assert Path(config.http_root).exists()
        assert Path(config.tftp_root).exists()

    def test_write_dnsmasq_conf(self, config: PXEServerConfig):
        server = PXEServer(config)
        server.ensure_dirs()
        path = server.write_dnsmasq_conf()
        assert path.exists()
        content = path.read_text()
        assert "interface=eth0" in content
        assert "192.168.99.1" in content
        assert "192.168.99.100" in content
        assert "192.168.99.200" in content
        assert config.tftp_root in content

    def test_write_nginx_conf(self, config: PXEServerConfig):
        server = PXEServer(config)
        server.ensure_dirs()
        path = server.write_nginx_conf()
        assert path.exists()
        content = path.read_text()
        assert "192.168.99.1:80" in content
        assert config.http_root in content

    def test_cleanup_no_processes(self, config: PXEServerConfig):
        server = PXEServer(config)
        server.ensure_dirs()
        server.cleanup()
        assert server._cleanup_done
        assert server.dnsmasq_proc is None
        assert server.nginx_proc is None

    def test_setup_signal_handlers(self, config: PXEServerConfig):
        server = PXEServer(config)
        server.setup_signal_handlers()
        # Just verify it doesn't crash
        assert True

    def test_temp_dir_creation(self, config: PXEServerConfig):
        config.temp_dir = ""
        server = PXEServer(config)
        assert server.temp_dir is not None
        assert server.temp_dir.exists()
        server.cleanup()

    def test_context_manager(self, config: PXEServerConfig):
        with PXEServer(config) as server:
            assert Path(config.http_root).exists()
            assert Path(config.tftp_root).exists()
        assert server._cleanup_done
