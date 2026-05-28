"""Tests for ipxe_installer models and autounattend."""

from ipxe_installer.models import (
    DSCConfig,
    Machine,
    Profile,
    PXEServerConfig,
    Stage,
    WindowsConfig,
)
from ipxe_installer.autounattend import render_autounattend, render_apply_dsc_ps1


class TestModels:
    def test_default_machine(self):
        m = Machine(mac_address="aa:bb:cc:dd:ee:ff")
        assert m.mac_address == "aa:bb:cc:dd:ee:ff"
        assert m.stages == ["nixos", "windows", "done"]
        assert not m.windows.unattended.enable

    def test_default_profile(self):
        p = Profile(name="test")
        assert p.name == "test"
        assert p.auto_install
        assert not p.auto_install_windows

    def test_dsc_config_defaults(self):
        d = DSCConfig()
        assert d.registry == {}
        assert d.features == []
        assert d.packages == {}

    def test_pxe_server_config_defaults(self):
        c = PXEServerConfig(interface="eth0")
        assert c.interface == "eth0"
        assert c.server_address == "192.168.99.1"
        assert c.dhcp_range_start == "192.168.99.100"
        assert c.serve_mode == "cli"


class TestAutounattend:
    def test_render_autounattend_basic(self):
        from ipxe_installer.models import WindowsUnattendedConfig

        config = WindowsUnattendedConfig(
            enable=True,
            partition_index=3,
            computer_name="TESTPC",
        )
        result = render_autounattend(config, DSCConfig())
        assert '<?xml version="1.0" encoding="utf-8"?>' in result
        assert "<unattend" in result
        assert "TESTPC" in result
        assert '<PartitionID>3</PartitionID>' in result
        assert "nixos" in result  # default user

    def test_render_autounattend_with_dsc(self):
        from ipxe_installer.models import WindowsUnattendedConfig

        config = WindowsUnattendedConfig(enable=True)
        result = render_autounattend(
            config, DSCConfig(),
            dsc_download_url="http://pxe/apply-dsc.ps1",
        )
        assert "apply-dsc.ps1" in result
        assert "apply-dsc.ps1" in result

    def test_render_apply_dsc_ps1_basic(self):
        result = render_apply_dsc_ps1(DSCConfig())
        assert "DSC v3 Bootstrap" in result
        assert "config.dsc.yaml" in result

    def test_render_apply_dsc_ps1_with_features(self):
        dsc = DSCConfig(features=["Microsoft-Windows-Subsystem-Linux",
                                  "VirtualMachinePlatform"])
        result = render_apply_dsc_ps1(dsc)
        assert "Microsoft-Windows-Subsystem-Linux" in result
        assert "VirtualMachinePlatform" in result

    def test_render_apply_dsc_ps1_with_registry(self):
        dsc = DSCConfig(registry={
            "HKLM\\Software\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU": {
                "NoAutoUpdate": 1,
            }
        })
        result = render_apply_dsc_ps1(dsc)
        assert "HKLM" in result
        assert "NoAutoUpdate" in result
