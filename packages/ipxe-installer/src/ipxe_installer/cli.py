"""CLI entry point for ipxe-installer."""

from __future__ import annotations

import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

import typer

from . import __version__
from .autounattend import render_apply_dsc_ps1, render_autounattend
from .iso_sync import ISOSync
from .models import DSCConfig, PXEServerConfig, Profile, WindowsUnattendedConfig
from .server import PXEServer
from .stages import StageManager


app = typer.Typer(
    name="ipxe-installer",
    help="PXE netboot server for unattended Windows/NixOS installs",
)


@app.callback(invoke_without_command=True)
def _main(
    ctx: typer.Context,
    version: bool = typer.Option(False, "--version", help="Show version", is_eager=True),
) -> None:
    if version:
        typer.echo(f"ipxe-installer v{__version__}")
        raise typer.Exit()


# ── Serve ──


@app.command()
def serve(
    interface: str = typer.Option("", "--interface", "-i", help="Network interface"),
    address: str = typer.Option("192.168.99.1", "--address", "-a", help="Server IP"),
    profile: str = typer.Option("", "--profile", "-p", help="Profile name"),
    mac: str = typer.Option("", "--mac", "-m", help="Target MAC address"),
    http_root: str = typer.Option("/srv/pxe", "--http-root", help="HTTP root"),
    tftp_root: str = typer.Option("/srv/tftp", "--tftp-root", help="TFTP root"),
    daemon: bool = typer.Option(False, "--daemon", "-d", help="Run as daemon"),
) -> None:
    """Start PXE netboot server (DHCP + TFTP + HTTP)."""
    config = PXEServerConfig(
        interface=interface,
        server_address=address,
        http_root=http_root,
        tftp_root=tftp_root,
        serve_mode="daemon" if daemon else "cli",
    )

    mgr = StageManager(http_root, address)

    # Setup machine if profile + MAC specified
    if profile and mac:
        prof = mgr.get_profile(profile)
        if not prof:
            typer.echo(f"Profile '{profile}' not found", err=True)
            raise typer.Exit(1)
        mgr.setup_machine(mac, prof)
        typer.echo(f"  [✓] Machine {mac} → stage {prof.stages[0]}")

        # Show kernel cmdline from stage script
        stage_file = Path(http_root) / "stages" / mac / f"stage-{prof.stages[0]}.ipxe"
        if stage_file.exists():
            for line in stage_file.read_text().splitlines():
                if line.startswith("kernel"):
                    typer.echo(f"  ├ cmdline: {line.split('vmlinuz ')[-1]}")
                    typer.echo(f"  └ initrd:  {line.split('kernel ')[-1].split()[1]}")
                    break

        # Show artifact sizes
        machines_dir = Path(http_root) / "machines" / mac
        for art in ["vmlinuz", "initrd", "disko.nix", "configuration.nix"]:
            f = machines_dir / art
            if f.exists():
                size = f.stat().st_size
                if size > 1024 * 1024:
                    typer.echo(f"  [{art}]  {size / 1024 / 1024:.0f} MB")
                elif size > 1024:
                    typer.echo(f"  [{art}]  {size / 1024:.0f} KB")
                else:
                    typer.echo(f"  [{art}]  {size} B")
            elif f.is_symlink():
                typer.echo(f"  [{art}]  → {os.readlink(str(f))} (broken)" if not f.exists() else "")

    # Write boot.ipxe
    mgr.write_boot_ipxe()
    typer.echo(f"  [✓] boot.ipxe updated")

    with PXEServer(config) as server:
        server.setup_signal_handlers()
        try:
            server.start_dnsmasq()
            typer.echo("  [✓] DHCP/TFTP running")
            server.start_nginx()
            typer.echo("  [✓] HTTP server running")
            server.start_log_relay()
            typer.echo("  [✓] Log relay running on port 8081")
            server.start_netconsole()
            typer.echo("  [✓] Kernel log listener on UDP 6666")

            typer.echo("\nPXE-boot the target machine to start.")
            typer.echo("Commands: advance <mac> | install <mac> | logs <mac> | tail <mac> | leases | list | quit")

            # Interactive loop
            while True:
                try:
                    cmd = input("netboot> ").strip()
                except (EOFError, KeyboardInterrupt):
                    break

                if not cmd:
                    continue
                if cmd == "quit":
                    break
                if cmd == "list":
                    _list(mgr, False)
                elif cmd == "leases":
                    lease_file = Path("/var/lib/misc/dnsmasq.leases")
                    if lease_file.exists():
                        typer.echo("DHCP Leases:")
                        for line in lease_file.read_text().strip().splitlines():
                            parts = line.split()
                            if len(parts) >= 4:
                                expiry, mac_addr, ip, hostname = parts[0], parts[1], parts[2], parts[3]
                                typer.echo(f"  {ip:16} {mac_addr:20} {hostname}")
                    else:
                        typer.echo("  No DHCP leases (target may not have booted)")
                elif cmd.startswith("logs "):
                    parts = cmd.split()
                    mac_arg = parts[1]
                    logs_dir = server.temp_dir / "logs"
                    http_log = logs_dir / mac_arg / "installer.log"
                    if http_log.exists():
                        typer.echo("=== Installer output ===")
                        typer.echo(http_log.read_text().rstrip())
                    kernel_entries = sorted(logs_dir.glob("*/kernel.log"))
                    for klog in kernel_entries:
                        typer.echo(f"\n=== Kernel log ({klog.parent.name}) ===")
                        typer.echo(klog.read_text().rstrip())
                    if not http_log.exists() and not kernel_entries:
                        typer.echo(f"  No logs for {mac_arg}")
                elif cmd.startswith("tail "):
                    parts = cmd.split()
                    mac_arg = parts[1]
                    log_file = server.temp_dir / "logs" / mac_arg / "installer.log"
                    nginx_access = server.temp_dir / "nginx-access.log"
                    pos = 0
                    nginx_pos = 0
                    typer.echo(f"Watching logs for {mac_arg}... (Ctrl+C to stop)")
                    try:
                        while True:
                            if log_file.exists():
                                size = log_file.stat().st_size
                                if size > pos:
                                    with open(log_file) as f:
                                        f.seek(pos)
                                        for line in f:
                                            typer.echo(line.rstrip())
                                    pos = size
                            if nginx_access.exists():
                                size = nginx_access.stat().st_size
                                if size > nginx_pos:
                                    with open(nginx_access) as f:
                                        f.seek(nginx_pos)
                                        for line in f:
                                            typer.echo(f"[HTTP] {line.rstrip()}")
                                    nginx_pos = size
                            time.sleep(2)
                    except KeyboardInterrupt:
                        pass
                elif cmd.startswith("install "):
                    parts = cmd.split()
                    mac_arg = parts[1]
                    prof = _get_profile_for_mac(mgr, mac_arg)
                    if not prof:
                        typer.echo(f"  Unknown MAC: {mac_arg}")
                        continue
                    log_file = server.temp_dir / "logs" / mac_arg / "installer.log"
                    log_file.parent.mkdir(parents=True, exist_ok=True)
                    typer.echo(f"  Running nixos-anywhere for {mac_arg}...")
                    success = mgr.nixos_anywhere(mac_arg, prof, log_file)
                    if success:
                        typer.echo(f"  [✓] NixOS install complete")
                        # Auto-advance to next stage
                        new = mgr.advance_stage(mac_arg, prof.stages, None)
                        typer.echo(f"  {mac_arg} → stage {new}")
                    else:
                        typer.echo(f"  [✗] NixOS install failed — check logs")
                elif cmd.startswith("advance "):
                    parts = cmd.split()
                    mac_arg = parts[1]
                    to_stage = parts[3] if len(parts) > 3 and parts[2] == "--to" else None
                    prof = _get_profile_for_mac(mgr, mac_arg)
                    if prof:
                        new = mgr.advance_stage(mac_arg, prof.stages, to_stage)
                        typer.echo(f"  {mac_arg} → stage {new}")
                    else:
                        typer.echo(f"  Unknown MAC: {mac_arg}")
                else:
                    typer.echo(f"  Unknown command: {cmd}")

        except Exception as e:
            typer.echo(f"ERROR: {e}", err=True)
            raise typer.Exit(1)


# ── Advance ──


@app.command()
def advance(
    mac: str = typer.Argument(..., help="Target MAC address"),
    to: str = typer.Option("", "--to", help="Stage to advance to"),
    http_root: str = typer.Option("/srv/pxe", "--http-root"),
) -> None:
    """Advance a machine to the next (or specified) stage."""
    mgr = StageManager(http_root, "")
    prof = _get_profile_for_mac(mgr, mac)
    if not prof:
        typer.echo(f"No profile found for MAC {mac}", err=True)
        raise typer.Exit(1)
    new = mgr.advance_stage(mac, prof.stages, to or None)
    typer.echo(f"{mac} → {new}")


# ── List ──


@app.command()
def list(
    http_root: str = typer.Option("/srv/pxe", "--http-root"),
) -> None:
    """List all machines and their current stages."""
    mgr = StageManager(http_root, "")
    _list(mgr, True)


def _list(mgr: StageManager, show_profiles: bool = True) -> None:
    """Print machine stage list."""
    if show_profiles:
        profiles = mgr.list_profiles()
        typer.echo("Profiles:")
        for p in profiles:
            typer.echo(f"  {p.name}: {', '.join(p.stages)}")
        typer.echo()

    # Scan machines dir
    machines_dir = mgr.http_root / mgr.MACHINES_DIR
    if machines_dir.exists():
        typer.echo("Machines:")
        for mdir in sorted(machines_dir.iterdir()):
            if mdir.is_dir():
                current = mgr.get_current_stage(mdir.name) or "unknown"
                typer.echo(f"  {mdir.name}: stage {current}")
    else:
        typer.echo("No machines configured.")


# ── Sync ISO ──


@app.command(name="sync-iso")
def sync_iso(
    release: str = typer.Option("latest", "--release", help="GitHub release tag"),
    output: str = typer.Option("/srv/pxe/windows", "--output", help="Output directory"),
    state: str = typer.Option("/var/lib/windows-iso-sync", "--state", help="State directory"),
    token: str = typer.Option("", "--token", help="GitHub token (for rate limiting)"),
) -> None:
    """Download Windows ISO from GitHub, reassemble, extract boot files."""
    syncer = ISOSync(
        release_tag=release,
        output_dir=output,
        state_dir=state,
        github_token=token,
    )
    try:
        updated = syncer.sync()
        if updated:
            typer.echo(f"ISO synced — boot files in {output}")
        else:
            typer.echo("Already up to date")
    except Exception as e:
        typer.echo(f"ERROR: {e}", err=True)
        raise typer.Exit(1)


# ── Gen Unattend ──


@app.command(name="gen-unattend")
def gen_unattend(
    output: str = typer.Option("/tmp/autounattend.xml", "--output", "-o"),
    partition: int = typer.Option(3, "--partition", help="Windows partition index"),
    user: str = typer.Option("nixos", "--user", help="Local username"),
    password: str = typer.Option("nixos123", "--password", help="Local password"),
    computer: str = typer.Option("DESKTOP", "--computer-name", help="Computer name"),
) -> None:
    """Generate autounattend.xml for unattended Windows install."""
    config = WindowsUnattendedConfig(
        enable=True,
        partition_index=partition,
        local_user=user,
        password=password,
        computer_name=computer,
    )
    result = render_autounattend(config, DSCConfig())
    Path(output).write_text(result)
    typer.echo(f"Written {output}")


# ── Gen DSC ──


@app.command(name="gen-dsc")
def gen_dsc(
    output: str = typer.Option("/tmp/apply-dsc.ps1", "--output", "-o"),
    registry: str = typer.Option("{}", "--registry", help="JSON registry config"),
    features: str = typer.Option("[]", "--features", help="JSON features list"),
) -> None:
    """Generate apply-dsc.ps1 for DSC v3 bootstrap."""
    import json
    dsc = DSCConfig(
        registry=json.loads(registry),
        features=json.loads(features),
    )
    result = render_apply_dsc_ps1(dsc)
    Path(output).write_text(result)
    typer.echo(f"Written {output}")


# ── Helpers ──


def _get_profile_for_mac(mgr: StageManager, mac: str) -> Optional[Profile]:
    """Find the profile for a MAC by scanning machine directories."""
    profiles = mgr.list_profiles()
    for prof in profiles:
        if mac in str(mgr.http_root / mgr.MACHINES_DIR / mac / ""):
            return prof
    # Fallback: return first profile
    return profiles[0] if profiles else None


def main() -> int:
    """Entry point for python -m ipxe_installer."""
    app()


if __name__ == "__main__":
    sys.exit(main())
