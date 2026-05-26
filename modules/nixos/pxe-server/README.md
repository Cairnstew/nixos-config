# PXE Server

PXE boot server powered by dnsmasq (DHCP + TFTP), nginx (HTTP), and iPXE.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.pxeServer.enable` | `false` | Enable PXE boot server |
| `my.services.pxeServer.interface` | `eth0` | Network interface for DHCP/TFTP |
| `my.services.pxeServer.dhcpRange` | `192.168.100.100,192.168.100.200` | DHCP lease range (start,end) |
| `my.services.pxeServer.serverIp` | `192.168.100.1` | Server IP for DHCP next-server, TFTP, and HTTP base URL |

## Usage

```nix
my.services.pxeServer = {
  enable = true;
  interface = "eth0";
  dhcpRange = "192.168.100.100,192.168.100.200";
  serverIp = "192.168.100.1";
};
```

## Boot Menu

The iPXE boot menu (`boot.ipxe`) provides:
- **NixOS** — netboot from official Hydra
- **Windows 11** — network install via wimboot (requires Windows boot files in `/srv/pxe/windows/`)
- **Local disk** — boot from local drive

## Notes

- Windows boot files must be populated in `/srv/pxe/windows/` separately (e.g., via `my.services.windowsIsoSync`)
- Default iPXE binaries are copied from nixpkgs at first activation
- HTTP server listens on port 8080
