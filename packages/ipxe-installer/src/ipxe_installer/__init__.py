"""ipxe-installer — PXE netboot server for unattended Windows/NixOS installs.

Provides a CLI tool and NixOS module for:
- PXE boot server (DHCP + TFTP + HTTP)
- Multi-stage installs (discover → nixos → windows → done)
- Automated Windows install (autounattend.xml generation)
- Automated NixOS install (disko + nixos-install orchestration)
- Windows ISO sync (download, reassemble, extract boot files)
- DSC v3 configuration bootstrap
"""

__version__ = "0.1.0"
