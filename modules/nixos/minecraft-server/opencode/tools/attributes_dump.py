#!/usr/bin/env python3
"""
attributes_dump.py — Build the attributes-dump mod, launch it in an isolated
NeoForge server instance with the pack's real mods, extract the JSON output.

Usage:
    python3 attributes_dump.py <modpack-dir> [--dry-run] [--timeout N]

The script:
1. Builds the dump mod JAR via nix-build (FOD, cached after first build).
2. Builds the NeoForge 21.1.249 server via nix-build (also cached).
3. Builds all packwiz mod JARs via nix-build (reuses packwiz2nix FODs, cached).
4. Creates a throwaway directory:
   - Symlinks pack's config/ read-only.
   - Copies dump mod JAR into mods/.
   - Writes minimal server.properties (port 25570, offline-mode, flat world).
   - Writes eula.txt, log4j2.xml, launch.sh.
5. Launches the NeoForge server, tails latest.log for [attributes-dump] marker.
6. On marker: copies attributes-dump.json to pack dir, tears down throwaway.
7. On timeout/crash: tears down and reports failure.
"""
import argparse
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def die(msg: str) -> None:
    print(f"attributes-dump: {msg}", file=sys.stderr)
    sys.exit(1)


# Which source-patches/<name> dump mod to build + which output file + marker to
# wait for. Default keeps the original attributes dump behavior; the item
# components dump reuses this exact launch/heap/logging harness via
# `--dump-mod item-components-dump` (the Java + this Python never reinvents the
# boot process — see ItemComponentsDump.java RUN LOG).
DUMP_MOD = "attributes-dump"


def find_repo_root() -> Path:
    """Find the nixos-config repo root (where flake.nix lives)."""
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL, text=True
        ).strip()
        return Path(out)
    except Exception:
        pass
    p = Path(__file__).resolve().parent
    while p != p.parent:
        if (p / "flake.nix").exists():
            return p
        p = p.parent
    die("cannot find repo root (flake.nix)")


def nix_build_expression(repo: Path, modpack_name: str) -> str:
    """Return the nix-build -E expression for the dump mod."""
    dump_dir = repo / "modules/nixos/minecraft-server/modpacks" / modpack_name / "source-patches" / DUMP_MOD
    build_mod_source = repo / "modules/nixos/minecraft-server/modpacks/build-mod-source.nix"
    rel_build = os.path.relpath(build_mod_source, dump_dir)
    return f'''
  let
    pkgs = import <nixpkgs> {{ config.allowUnfree = true; }};
    buildModSource = import {rel_build} {{ inherit pkgs; }};
  in
    import ./default.nix {{ inherit buildModSource; inherit (pkgs) curl unzip cacert; }}
'''.strip()


def nix_build_server() -> str:
    """Return the nix-build -E expression for the NeoForge 21.1.249 server."""
    return '''
  let
    nix-minecraft = builtins.getFlake "github:Infinidoge/nix-minecraft";
    pkgs = import <nixpkgs> { 
      overlays = [ nix-minecraft.overlays.default ];
      config.allowUnfree = true;
    };
  in
    pkgs.neoforgeServers.neoforge-1_21_1-21_1_249
'''.strip()


def build_dump_mod(repo: Path, modpack_name: str) -> Path:
    """Build the dump mod JAR, return its store path."""
    dump_dir = repo / "modules/nixos/minecraft-server/modpacks" / modpack_name / "source-patches" / DUMP_MOD
    expr = nix_build_expression(repo, modpack_name)
    print(f"[attributes-dump] Building dump mod JAR...")
    try:
        out = subprocess.check_output(
            ["nix-build", "-E", expr, "--no-out-link"],
            cwd=str(dump_dir), stderr=subprocess.STDOUT, text=True, timeout=600
        ).strip().splitlines()[-1]
    except subprocess.CalledProcessError as e:
        die(f"nix-build dump mod failed:\n{e.output}")
    except subprocess.TimeoutExpired:
        die("nix-build dump mod timed out (600s)")
    jar = Path(out)
    if not jar.exists():
        die(f"dump mod JAR not found at {out}")
    print(f"[attributes-dump] Dump mod JAR: {jar}")
    return jar


def build_neoforge_server() -> Path:
    """Build the NeoForge 21.1.249 server, return its store path."""
    expr = nix_build_server()
    print(f"[attributes-dump] Building NeoForge 21.1.249 server...")
    try:
        out = subprocess.check_output(
            ["nix-build", "-E", expr, "--no-out-link"],
            stderr=subprocess.STDOUT, text=True, timeout=600
        ).strip().splitlines()[-1]
    except subprocess.CalledProcessError as e:
        die(f"nix-build neoforge server failed:\n{e.output}")
    except subprocess.TimeoutExpired:
        die("nix-build neoforge server timed out (600s)")
    server_dir = Path(out)
    if not server_dir.exists():
        die(f"NeoForge server dir not found at {out}")
    print(f"[attributes-dump] NeoForge server (store): {server_dir}")
    return server_dir


def build_packwiz_mods(pack_dir: Path, repo: Path) -> Path:
    """Build all packwiz mod JARs via Nix linkFarm (reuses packwiz2nix FODs, cached).
    Returns the path to the output dir containing .jar symlinks (no mods/ subdir)."""
    if not (pack_dir / "checksums.json").exists():
        die(f"checksums.json not found in {pack_dir}")

    # Use the static link-farm-mods.nix — no Python-generated Nix, no $out escaping.
    link_farm_nix = Path(__file__).parent / "link-farm-mods.nix"
    if not link_farm_nix.exists():
        die(f"link-farm-mods.nix not found at {link_farm_nix}")

    expr = f'import {link_farm_nix} {{ repo = {repo}; packName = "{pack_dir.name}"; }}'
    print(f"[attributes-dump] Building packwiz mod jars via Nix linkFarm (cached FODs)...")
    try:
        out = subprocess.check_output(
            ["nix-build", "-E", expr, "--no-out-link"],
            stderr=subprocess.STDOUT, text=True, timeout=600
        ).strip().splitlines()[-1]
    except subprocess.CalledProcessError as e:
        die(f"nix-build packwiz mods failed:\n{e.output}")
    except subprocess.TimeoutExpired:
        die("nix-build packwiz mods timed out (600s)")
    out_path = Path(out)
    jar_count = len(list(out_path.glob("*.jar")))
    print(f"[attributes-dump] Packwiz mods: {jar_count} jars at {out_path}")
    return out_path


def copy_server_to_writable(server_store: Path) -> Path:
    """Copy the nix store server dir to a writable temp location.
    FMLPaths tries to create mods/ in the server dir, which is read-only in the nix store."""
    server_writable = Path(tempfile.mkdtemp(prefix="mc-neoforge-server-"))
    print(f"[attributes-dump] Copying server to writable: {server_writable}")
    for item in server_store.iterdir():
        dest = server_writable / item.name
        if item.is_dir():
            shutil.copytree(item, dest)
        else:
            shutil.copy2(item, dest)
    print(f"[attributes-dump] Server copy complete")
    return server_writable


def setup_isolated_clone(
    pack_dir: Path,
    dump_jar: Path,
    server_dir: Path,
    packwiz_mods_path: Path | None = None,
    exclude_mods: list[str] | None = None,
    vanilla_only: bool = False,
) -> Path:
    """Create a throwaway server directory with symlinked mods + config.
    packwiz_mods_path is the linkFarm output dir containing .jar files directly.
    exclude_mods: list of mod slugs to skip (e.g. ['reliquified-artifacts', 'create']).
    vanilla_only: if True, skip all pack mods (only dump mod + NeoForge)."""
    tmpdir = Path(tempfile.mkdtemp(prefix="mc-attributes-dump-"))
    print(f"[attributes-dump] Isolated clone: {tmpdir}")

    mods_dir = tmpdir / "mods"
    mods_dir.mkdir()

    if not vanilla_only and packwiz_mods_path is not None:
        # Build exclusion set: match mod slug against jar filename (modname-version.jar)
        exclude_set = set()
        if exclude_mods:
            for jar in packwiz_mods_path.glob("*.jar"):
                jar_stem = jar.stem.lower().replace("_", "-")
                for ex in exclude_mods:
                    if ex.lower() in jar_stem:
                        exclude_set.add(jar.name)
                        print(f"[attributes-dump] Excluding: {jar.name}")
                        break

        # Symlink packwiz mod JARs into the tmpdir's mods/
        for jar in packwiz_mods_path.glob("*.jar"):
            if jar.name not in exclude_set:
                os.symlink(jar, mods_dir / jar.name)

        # Also symlink mods into the server dir — FML discovers mods from server dir, not gameDir
        server_mods = server_dir / "mods"
        server_mods.mkdir(exist_ok=True)
        for jar in mods_dir.iterdir():
            if jar.is_file() and jar.name not in exclude_set:
                dest = server_mods / jar.name
                if not dest.exists():
                    os.symlink(jar.resolve(), dest)
    else:
        if vanilla_only:
            print(f"[attributes-dump] Vanilla-only mode: skipping all pack mods")

    # Symlink dump mod JAR into mods/ (both tmpdir and server dir)
    dump_link = mods_dir / dump_jar.name
    if not dump_link.exists():
        os.symlink(dump_jar, dump_link)
    # NeoForge discovers mods from server dir, not gameDir — must also be there
    server_mods_dir = server_dir / "mods"
    server_mods_dir.mkdir(exist_ok=True)
    server_dump_link = server_mods_dir / dump_jar.name
    if not server_dump_link.exists():
        os.symlink(dump_jar.resolve(), server_dump_link)

    # Symlink pack's config/ read-only (server dir + tmpdir)
    pack_config = pack_dir / "config"
    if pack_config.is_dir():
        os.symlink(pack_config, tmpdir / "config", target_is_directory=True)
        server_config = server_dir / "config"
        if not server_config.exists():
            os.symlink(pack_config, server_config, target_is_directory=True)

    # Write server.properties to server dir (FML uses server dir as install dir)
    (server_dir / "server.properties").write_text(
        "server-port=25570\n"
        "online-mode=false\n"
        "level-type=minecraft\\:flat\n"
        "generator-settings={\"layers\":[{\"block\":\"minecraft\\:air\",\"height\":1}],\"biome\":\"minecraft\\:plains\"}\n"
        "max-players=1\n"
        "spawn-protection=0\n"
        "view-distance=4\n"
        "simulation-distance=4\n"
    )
    (server_dir / "eula.txt").write_text("eula=true\n")
    (server_dir / "logs").mkdir(exist_ok=True)
    (server_dir / "world").mkdir(exist_ok=True)

    # Also write server.properties to tmpdir (backup)
    (tmpdir / "server.properties").write_text(
        "server-port=25570\n"
        "online-mode=false\n"
        "level-type=minecraft\\:flat\n"
        "generator-settings={\"layers\":[{\"block\":\"minecraft\\:air\",\"height\":1}],\"biome\":\"minecraft\\:plains\"}\n"
        "max-players=1\n"
        "spawn-protection=0\n"
        "view-distance=4\n"
        "simulation-distance=4\n"
    )
    (tmpdir / "eula.txt").write_text("eula=true\n")
    (tmpdir / "logs").mkdir(exist_ok=True)
    (tmpdir / "world").mkdir(exist_ok=True)

    # Write custom log4j2.xml — logs go to BOTH server dir and tmpdir so
    # the tailer can find the marker regardless of which path the JVM writes to.
    log4j_config = tmpdir / "log4j2.xml"
    log4j_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="WARN">
    <Appenders>
        <RollingFile name="File" fileName="{server_dir}/logs/latest.log"
                     filePattern="{server_dir}/logs/latest-%i.log.gz"
                     immediateFlush="true">
            <PatternLayout pattern="[%d{{HH:mm:ss.SSS}}] [%t/%level] %logger{{36}}: %msg%n"/>
            <SizeBasedTriggeringPolicy size="100MB"/>
        </RollingFile>
        <RollingFile name="File2" fileName="{tmpdir}/logs/latest.log"
                     filePattern="{tmpdir}/logs/latest-%i.log.gz"
                     immediateFlush="true">
            <PatternLayout pattern="[%d{{HH:mm:ss.SSS}}] [%t/%level] %logger{{36}}: %msg%n"/>
            <SizeBasedTriggeringPolicy size="100MB"/>
        </RollingFile>
        <Console name="Console" target="SYSTEM_OUT">
            <PatternLayout pattern="[%d{{HH:mm:ss.SSS}}] [%t/%level] %logger{{36}}: %msg%n"/>
        </Console>
    </Appenders>
    <Loggers>
        <Root level="INFO">
            <AppenderRef ref="File"/>
            <AppenderRef ref="File2"/>
            <AppenderRef ref="Console"/>
        </Root>
    </Loggers>
</Configuration>
"""
    log4j_config.write_text(log4j_xml)

    # Write a launcher script
    # Fixed 4G heap — well above the 1.5G minimum for this 280-mod pack, well below
    # 16G waste for a ~28s task. Xms=Xmx avoids GC pauses from heap resizing.
    # JDK 21 defaults to G1GC on server-class hardware; no explicit GC flags needed.
    unix_args = server_dir / "libraries/net/neoforged/neoforge/21.1.249/unix_args.txt"
    launcher = tmpdir / "launch.sh"
    launcher.write_text(f"""#!/bin/sh
cd '{server_dir}'
java \\
  -Xms4G -Xmx4G \\
  -Xlog:gc*:file={tmpdir}/logs/gc.log:time,uptime,level,tags \\
  -DgameDir='{tmpdir}' \\
  -Dlog4j.configurationFile='{log4j_config}' \\
  @{unix_args} \\
  --nogui
""")
    launcher.chmod(0o755)

    return tmpdir


def launch_and_wait(tmpdir: Path, server_dir: Path, timeout: int = 1800) -> Path | None:
    """
    Launch the NeoForge server, tail latest.log for the dump marker.
    Returns the path to the dump JSON on success, None on failure.
    Checks both server dir and gameDir tmpdir for the JSON output.

    Strategy: scan logs with offset tracking (no re-read from start), kill the
    process group immediately once the marker is seen.  The nix-shell wrapper
    process does not reliably exit after the Java server finishes, so we never
    rely on proc.poll() for success detection — the marker is the ground truth.

    Heartbeat: prints elapsed time every 30s so long runs don't look like hangs.
    """
    marker = f"[{DUMP_MOD}] COMPLETE:"
    log_path_server = server_dir / "logs" / "latest.log"
    log_path_tmpdir = tmpdir / "logs" / "latest.log"
    attrs_json_server = server_dir / f"{DUMP_MOD}.json"
    attrs_json_tmpdir = tmpdir / f"{DUMP_MOD}.json"

    launcher = tmpdir / "launch.sh"
    if not launcher.exists():
        die(f"launch.sh not found at {launcher}")

    print(f"[attributes-dump] Launching server (timeout {timeout}s)...")
    launch_cmd = f"nix-shell -p openjdk21 --run '{launcher}'"
    # Do NOT capture stdout as a pipe. The log4j2.xml Console appender mirrors
    # every log line to SYSTEM_OUT; if that stream is an undrained PIPE, once
    # cumulative console output exceeds the 64KB pipe buffer, `main` blocks in
    # OutputStreamManager.flush and the whole server wedges (frozen RollingFile
    # logs, no dump). The tailer reads the RollingFile logs + JSON file, so the
    # console stream exists only for humans — route it to a file instead.
    console_log = open(tmpdir / "logs" / "console.log", "wb")
    proc = subprocess.Popen(
        launch_cmd,
        cwd=str(tmpdir),
        stdout=console_log,
        stderr=subprocess.STDOUT,
        shell=True,
        preexec_fn=os.setsid,
    )
    console_log.close()

    start_time = time.time()
    marker_found = False
    # Track file offsets so we only scan new content each iteration
    log_offsets: dict[str, int] = {}
    last_heartbeat = 0

    def _heartbeat() -> None:
        """Print elapsed time every 30s so long waits don't look like hangs."""
        nonlocal last_heartbeat
        elapsed = int(time.time() - start_time)
        if elapsed - last_heartbeat >= 30:
            print(f"[attributes-dump] ... still waiting, {elapsed}s elapsed ({elapsed // 60}m{elapsed % 60}s)")
            last_heartbeat = elapsed

    def _scan_logs() -> bool:
        """Scan log files from last-known offset. Return True if marker found."""
        nonlocal log_offsets
        for lp in [log_path_server, log_path_tmpdir]:
            key = str(lp)
            try:
                size = lp.stat().st_size
            except OSError:
                continue
            offset = log_offsets.get(key, 0)
            if size <= offset:
                continue
            try:
                with open(lp, "r", errors="replace") as f:
                    f.seek(offset)
                    for line in f:
                        if marker in line:
                            print(f"[attributes-dump] {line.strip()}")
                            return True
                    log_offsets[key] = f.tell()
            except OSError:
                continue
        return False

    def _kill_server() -> None:
        """Terminate the entire process tree (nix-shell → bash → java)."""
        try:
            pgid = os.getpgid(proc.pid)
            os.killpg(pgid, signal.SIGTERM)
        except (ProcessLookupError, PermissionError):
            pass
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
        # Force-kill if still alive
        try:
            pgid = os.getpgid(proc.pid)
            os.killpg(pgid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            pass

    try:
        while time.time() - start_time < timeout:
            # 1. Check for the dump file directly (fastest success path —
            #    the mod writes the JSON before logging the marker)
            if attrs_json_server.exists() or attrs_json_tmpdir.exists():
                # Give the marker one more scan cycle to appear in the log
                if _scan_logs():
                    marker_found = True
                else:
                    # Dump file exists but marker not yet in log — accept it
                    marker_found = True
                    print(f"[attributes-dump] Dump JSON found (marker pending in log)")
                break

            # 2. Scan log files for the marker
            if _scan_logs():
                marker_found = True
                break

            # 3. Check if the process already exited (crash / normal exit)
            if proc.poll() is not None:
                print(f"[attributes-dump] Server process exited with code {proc.returncode}")
                # Do one final scan — the marker may be in the log
                if _scan_logs():
                    marker_found = True
                break

            _heartbeat()
            time.sleep(2)

        if not marker_found:
            if proc.poll() is not None:
                print(f"[attributes-dump] Server crashed (exit code {proc.returncode})")
            else:
                print(f"[attributes-dump] Timeout after {timeout}s")
    finally:
        # Always kill the server — the nix-shell wrapper does not reliably
        # exit after the Java process finishes.
        _kill_server()

    # Check both locations for the JSON output (may exist even if marker was missed)
    if marker_found:
        if attrs_json_server.exists():
            return attrs_json_server
        if attrs_json_tmpdir.exists():
            return attrs_json_tmpdir
    return None


def main():
    global DUMP_MOD
    parser = argparse.ArgumentParser(description="Dump data via isolated NeoForge server")
    parser.add_argument("modpack_dir", help="Path to the modpack directory (e.g. modules/nixos/minecraft-server/modpacks/AllTheTech)")
    parser.add_argument("--dump-mod", default="attributes-dump",
                        help="Dump mod under source-patches/<name> to build+run (default: attributes-dump)")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be done without doing it")
    parser.add_argument("--timeout", type=int, default=1800, help="Server timeout in seconds (default 1800)")
    parser.add_argument("--keep-on-failure", action="store_true", help="Keep isolated clone dir on failure (for debugging)")
    parser.add_argument("--exclude-mods", nargs="*", default=[],
                        help="Mod slugs to exclude from the server (e.g. 'reliquified-artifacts create dtstilllife')")
    parser.add_argument("--vanilla-baseline", action="store_true",
                        help="Generate vanilla baseline from the full pack dump (filters to vanilla entities only)")
    args = parser.parse_args()
    DUMP_MOD = args.dump_mod

    pack_dir = Path(args.modpack_dir).resolve()
    if not (pack_dir / "pack.toml").exists():
        die(f"{pack_dir}/pack.toml not found — is this a modpack directory?")

    repo = find_repo_root()
    modpack_name = pack_dir.name

    if args.dry_run:
        mode = "vanilla-only baseline" if args.vanilla_baseline else "full pack dump"
        print(f"[dry-run] Mode: {mode}  (dump-mod: {DUMP_MOD})")
        print(f"[dry-run] Would build dump mod for {modpack_name}")
        if not args.vanilla_baseline:
            print(f"[dry-run] Would build packwiz mod jars via Nix derivation")
        print(f"[dry-run] Would build NeoForge 21.1.249 server")
        print(f"[dry-run] Would create isolated clone in /tmp/mc-attributes-dump-*")
        print(f"[dry-run] Would symlink mods/ + config/, copy dump JAR, launch server")
        print(f"[dry-run] Would tail logs for [{DUMP_MOD}] marker (timeout {args.timeout}s)")
        if args.vanilla_baseline:
            print(f"[dry-run] Would save baseline to {pack_dir / 'vanilla-attributes-baseline.json'}")
        return

    # Phase timestamps for wall-clock breakdown
    t_start = time.time()

    # Step 1: Build dump mod
    dump_jar = build_dump_mod(repo, modpack_name)
    t_dump_mod = time.time()
    print(f"[attributes-dump] Phase timing — dump mod build: {t_dump_mod - t_start:.1f}s")

    # Step 1b: Build packwiz mod jars via Nix (reuses packwiz2nix FODs) — skip for vanilla-only
    packwiz_out = None
    if not args.vanilla_baseline:
        packwiz_out = build_packwiz_mods(pack_dir, repo)
    t_packwiz = time.time()
    print(f"[attributes-dump] Phase timing — packwiz mods build: {t_packwiz - t_dump_mod:.1f}s")

    # Step 2: Build NeoForge server
    server_store = build_neoforge_server()
    t_server = time.time()
    print(f"[attributes-dump] Phase timing — NeoForge server build: {t_server - t_packwiz:.1f}s")

    # Step 2b: Copy server to writable location
    server_dir = copy_server_to_writable(server_store)
    t_copy = time.time()
    print(f"[attributes-dump] Phase timing — server copy: {t_copy - t_server:.1f}s")

    # Step 3: Setup isolated clone
    tmpdir = setup_isolated_clone(
        pack_dir, dump_jar, server_dir, packwiz_out,
        exclude_mods=args.exclude_mods,
        vanilla_only=args.vanilla_baseline,
    )
    t_setup = time.time()
    print(f"[attributes-dump] Phase timing — isolated clone setup: {t_setup - t_copy:.1f}s")
    print(f"[attributes-dump] Phase timing — pre-launch total: {t_setup - t_start:.1f}s")
    success = False

    try:
        # Step 4: Launch, tail, wait
        result = launch_and_wait(tmpdir, server_dir, timeout=args.timeout)

        if result is None:
            if args.keep_on_failure:
                print(f"[attributes-dump] FAILED — logs at {tmpdir / 'logs'} and {server_dir / 'logs'} (kept for debugging)")
                return
            die("attribute dump failed — check logs")

        # Step 5: Copy result
        if args.vanilla_baseline:
            out_path = pack_dir / "vanilla-attributes-baseline.json"
            shutil.copy2(result, out_path)
            print(f"[attributes-dump] Wrote vanilla baseline: {out_path}")
        else:
            out_path = pack_dir / f"{DUMP_MOD}.json"
            shutil.copy2(result, out_path)
            print(f"[attributes-dump] Wrote {out_path}")

        t_end = time.time()
        size = out_path.stat().st_size
        print(f"[attributes-dump] Done ({size:,} bytes)")
        print(f"[attributes-dump] Phase timing — server runtime: {t_end - t_setup:.1f}s")
        print(f"[attributes-dump] Phase timing — total wall clock: {t_end - t_start:.1f}s ({(t_end - t_start) / 60:.1f}min)")
        success = True

    finally:
        if success or not args.keep_on_failure:
            print(f"[attributes-dump] Cleaning up {tmpdir}")
            shutil.rmtree(tmpdir, ignore_errors=True)
            print(f"[attributes-dump] Cleaning up server copy {server_dir}")
            shutil.rmtree(server_dir, ignore_errors=True)


if __name__ == "__main__":
    main()

# ## RUN LOG
# ### 2026-09-08 — launch_and_wait default timeout: 300s too short for 280-mod packs
# AllTheTech (281 mods) takes ~9 minutes to load past FMLLoadCompleteEvent. The old
# default of 300s in launch_and_wait() consistently timed out, while main()'s default
# was already 600s. Fixed by aligning launch_and_wait's default to 600s. Verified:
# dump completed at 541s wall time on a clean run (server dir log shows marker at
# 21:00:06, dump JSON was 888KB with 84 default_attributes and 88 attribute groups).
#
# ### 2026-09-08 — launch_and_wait: offset-based _scan_logs() can miss the marker
# Intermittent timing-out despite the dump actually succeeding. The offset-based log
# scanning in _scan_logs() tracks byte offsets per file, but bursts of logging between
# scan iterations (>2s apart) can advance the offset past the marker line, causing
# subsequent scans to skip it. Meanwhile step 1 (attrs_json_server.exists()) is the
# reliable path but also runs only once per loop iteration. The fix is to always check
# for the JSON file (attrs_json_server / attrs_json_tmpdir) FIRST and accept it even
# without the marker, since the marker is just a courtesy. The current code already
# does this in the right order, but the 2s sleep between iterations means a ~3min
# server load sequence can overlap with a scan cycle boundary. If this keeps happening,
# increase the scan frequency (time.sleep(1) instead of 2) or check both files in
# the same iteration (currently step 1 checks JSON, step 2 checks logs — should merge).
#
# ### 2026-09-12 — log4j2 RollingFile never flushed: log lost on every run
# The log4j2.xml config used SizeBasedTriggeringPolicy with 100MB threshold. Since the
# log file only reaches ~63KB during a 541s run, the RollingFile appender never flushes
# its in-memory buffer to disk. The JVM ran for 598s but only 2s of log was written.
# Fix: added immediateFlush="true" to both RollingFile appenders. Also confirmed:
# AttributesDump hooks FMLLoadCompleteEvent (before world gen), so the entire 541s is
# mod loading time, NOT world gen. Re-running with the fix will show the actual phase
# breakdown in the log.
#
# ### 2026-09-12 — added heartbeat + phase timestamps
# Long runs (11min+) look indistinguishable from hangs. Added: (1) heartbeat every 30s
# in launch_and_wait printing "[attributes-dump] ... still waiting, Ns elapsed", and
# (2) phase timestamps in main() measuring dump mod build, packwiz mods build,
# NeoForge server build, server copy, isolated clone setup, server runtime, and total
# wall clock. Timeout bumped to 1800s for the diagnostic run (JarJar alone takes ~11min).
#
# ### 2026-09-12 — flush hypothesis DISPROVED: immediateFlush is REQUIRED, not harmful
# Reverted immediateFlush="true" from both appenders, cleared Python .pyc cache,
# ran fresh with 900s timeout → server still did NOT complete (1024-line log ending at
# mixin warnings, no dump). The flush does NOT cause the slowdown. In fact, WITHOUT
# immediateFlush the COMPLETE marker stays in a log buffer and never gets written to
# disk, so the script times out even if the server actually completed. The 1759s run
# WITH immediateFlush DID produce the dump successfully. Root cause of the 1759s time:
# the server genuinely takes ~30 minutes for JarJar dependency resolution with 363 mods
# (282 top-level + 81 JarJar nested). The original 541s run was likely with a different
# mod configuration. Default timeout set to 1800s. Kept immediateFlush="true".
#
# ### 2026-09-12 — REAL ROOT CAUSE: undrained stdout=PIPE deadlock, not slow JarJar
# The "1759s / ~30min JarJar" conclusion above is WRONG, and the "541s" baseline is not
# the real cost either. The actual cause of the multi-minute and timeout-during-stall
# runs is a deadlock: launch_and_wait() opened Popen(stdout=PIPE) but never drained
# proc.stdout, and log4j2.xml's <Console target="SYSTEM_OUT"> mirror-appender writes every
# log line to that pipe. Once cumulative console output exceeds the Linux pipe buffer
# (64KB), java's main thread blocks in OutputStreamManager.flush forever. The JVM makes
# NO JarJar progress during these stalls — jstack shows main wedged on FileOutputStream
# write with near-zero CPU delta across minutes (verified 2343ms CPU at both t+262s and
# t+398s), and BOTH RollingFile logs freeze at exactly ~64KB of output. It is a starvation
# on a full pipe, not genuine JarJar computation. (The four earlier jstacks at t+5/65/185/305s
# that showed a LIVE thread in Resolver.makeGraph were from a run launched via a plain shell
# script, not through this PIPE — so they saw real JarJar work, but they were on a DIFFERENT
# launch path and never reached this deadlock.)
# Fix (this commit): route Popen stdout to a file (console.log in the clone's logs/), since
# the tailer only reads the RollingFile logs + the dump JSON. After the fix the ENTIRE JVM
# phase — JarJar dependency resolution, mod loading, and the attribute dump — completes in
# **30s of server runtime** (COMPLETE at 22:16:37, JVM 99-430% CPU throughout, dump written).
# Real total wall clock for a full attributes-regenerate: ~190s, dominated by the nix
# packwiz-mod linkFarm build (157s; skips to ~5s when FODs are cached), NOT by the JVM.
# The eula.txt "instant-death" failure mode is a SEPARATE, earlier/later crash (missing/
# empty eula acceptance), not the explanation for these CPU-heavy or stalled observations.
# Default timeout can stay 1800s (harmless) but a fixed run needs ~30s of it.
# ### 2026-09-13 — --dump-mod parameter (drives the item-components dump too)
# The launch/heap/logging harness was attributes-dump-specific (marker string,
# output json name, source-patches dir). Yet the item components dump needs the
# EXACT same isolated NeoForge boot — the stdout-pipe deadlock fix, immediateFlush
# log4j, heartbeat, phase timing, marker-tail detection are all reusable as-is.
# Added a module-level DUMP_MOD (default "attributes-dump") and --dump-mod arg;
# the marker, output json filename, and source-patches/<name> path all derive
# from it. ItemComponentsDump.java (source-patches/item-components-dump) writes
# item-components-dump.json and prints "[item-components-dump] COMPLETE:" which
# this tailer now finds. Verified end-to-end: 22202 items dumped in ~30s server
# runtime via the identical launch path.
# NOTE: downlevel callers of attributes_dump.py keep default behavior; mc-pack.py
# gained cmd_item_components_regenerate which passes --dump-mod item-components-dump.
