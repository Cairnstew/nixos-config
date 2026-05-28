"""Domain models for ipxe-installer configuration."""

from __future__ import annotations

from typing import Optional
from pydantic import BaseModel, Field


class WindowsUnattendedConfig(BaseModel):
    """Configuration for unattended Windows installation."""

    enable: bool = False
    partition_index: int = 3
    local_user: str = "nixos"
    password: str = "nixos123"
    timezone: str = "Pacific Standard Time"
    edition: str = "Windows 11 Pro"
    computer_name: str = "DESKTOP"
    disable_recovery: bool = True


class WindowsConfig(BaseModel):
    """Windows-related configuration."""

    unattended: WindowsUnattendedConfig = WindowsUnattendedConfig()
    boot_dir: str = "/srv/pxe/windows"


class NixOSAutoInstallConfig(BaseModel):
    """Configuration for automated NixOS installation."""

    enable: bool = False
    disko_config: dict = {}
    nixos_config: str = ""
    label: str = "nixos"


class NixOSConfig(BaseModel):
    """NixOS-related configuration."""

    auto_install: NixOSAutoInstallConfig = NixOSAutoInstallConfig()
    ipxe_url: str = (
        "https://github.com/nix-community/nixos-images/releases/download/"
        "nixos-unstable/netboot-x86_64-linux.ipxe"
    )


class DSCConfig(BaseModel):
    """DSC v3 configuration (nix-attrs form, rendered to YAML)."""

    registry: dict = {}
    features: list[str] = []
    packages: dict = {}
    ps_modules: list[str] = []


class Stage(BaseModel):
    """A single install stage."""

    name: str  # discover, nixos, windows, done


class Machine(BaseModel):
    """A target machine configuration."""

    mac_address: str
    stages: list[str] = ["nixos", "windows", "done"]
    windows: WindowsConfig = WindowsConfig()
    nixos: NixOSConfig = NixOSConfig()
    dsc_config: DSCConfig = DSCConfig()
    server_address: str = "192.168.99.1"


class Profile(BaseModel):
    """A reusable boot profile."""

    name: str
    description: str = ""
    stages: list[str] = ["nixos", "windows", "done"]
    windows: WindowsConfig = WindowsConfig()
    nixos: NixOSConfig = NixOSConfig()
    dsc_config: DSCConfig = DSCConfig()
    auto_install: bool = True
    auto_install_windows: bool = False


class PXEServerConfig(BaseModel):
    """Top-level PXE server configuration."""

    interface: str = ""
    server_address: str = "192.168.99.1"
    subnet_prefix: int = 24
    dhcp_range_start: str = "192.168.99.100"
    dhcp_range_end: str = "192.168.99.200"
    dhcp_lease_time: str = "1d"
    tftp_root: str = "/srv/tftp"
    http_root: str = "/srv/pxe"
    temp_dir: str = ""
    serve_mode: str = "cli"  # cli | daemon
    profile: Optional[str] = None
    target_mac: Optional[str] = None
    windows_enable: bool = True
    nixos_enable: bool = True
