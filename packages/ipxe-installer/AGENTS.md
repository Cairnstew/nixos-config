# ipxe-installer — Agent Guide

## Structure

```
src/ipxe_installer/
├── __init__.py      # Package metadata
├── __main__.py      # python -m entry point
├── cli.py           # Typer CLI: serve, advance, list, sync-iso, gen-unattend, gen-dsc
├── server.py        # dnsmasq + nginx lifecycle
├── stages.py        # Stage state machine, iPXE script gen
├── autounattend.py  # Windows autounattend.xml + apply-dsc.ps1 generation
├── iso_sync.py      # GitHub release → ISO reassembly → boot file extraction
├── models.py        # Pydantic models (Machine, Profile, PXEServerConfig, etc.)
└── templates/       # Jinja2 templates
    ├── autounattend.xml.j2
    ├── apply-dsc.ps1.j2
    ├── boot.ipxe.j2
    ├── dnsmasq.conf.j2
    ├── nginx.conf.j2
    └── stage.ipxe.j2

modules/
├── nixos.nix        # NixOS module (thin wrapper)
├── builder.nix      # Netboot installer derivation (kernel+initrd)
├── flake.nix        # uv2nix project config
├── python-env.nix   # uv2nix Python env
└── pyproject.nix    # pyproject.toml generator
```

## Key Design

- **Python CLI** handles all runtime: DHCP/TFTP (dnsmasq), HTTP (nginx), stage state machine
- **NixOS module** is thin: firewall, tmpfiles, systemd services, package install
- **Builder** (`builder.nix`) is the only Nix derivation — builds custom netboot kernel+initrd
- **autounattend.xml** generated at runtime via Jinja2 (no Nix string escaping)
- **Windows ISO sync** in Python with proper error handling

## Build

```bash
nix build              # via buildPythonApplication
nix run .# -- --help   # via uv2nix dev flake
```

## Adding Features

1. Add model to `models.py` if new config is needed
2. Add templates to `templates/` if new files need generation
3. Add commands to `cli.py`
4. Update `modules/nixos.nix` if new NixOS options are needed
5. Write tests in `tests/`
