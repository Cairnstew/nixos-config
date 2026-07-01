#!/usr/bin/env python3
import sys
import argparse
import uuid
import hashlib
from pathlib import Path

from save_file import SaveFile


def cmd_info(args):
    sf = SaveFile.from_path(Path(args.save_file))
    info = sf.info()
    for k, v in info.items():
        print(f"{k}: {v}")


def cmd_thumbnail(args):
    sf = SaveFile.from_path(Path(args.save_file))
    png = sf.extract_thumbnail()
    out = Path(args.output) if args.output else sf.path.with_suffix(".png")
    out.write_bytes(png)
    print(f"Thumbnail extracted: {out} ({len(png)} bytes)")


def cmd_inject(args):
    sf = SaveFile.from_path(Path(args.save_file))
    png_bytes = Path(args.png_file).read_bytes()
    new_data = sf.inject_thumbnail(png_bytes)
    out = Path(args.output) if args.output else sf.path
    out.write_bytes(new_data)
    print(f"Thumbnail injected: {out}")


def cmd_connect(args):
    from ipc import FoundationIPC, FoundationIPCError
    try:
        ipc = FoundationIPC(host=args.host, port=args.port)
        ipc.connect()
    except FoundationIPCError as e:
        print(f"{e}")
        return 1
    try:
        ver = ipc.ping()
        print(f"Connected to Foundation (version: {ver})")
    except FoundationIPCError:
        print("Connected (ping failed)")
    print("Enter Lua code to evaluate. Type 'exit' to quit.")
    try:
        while True:
            try:
                line = input("lua> ").strip()
            except EOFError:
                break
            if not line:
                continue
            if line.lower() in ("exit", "quit"):
                break
            try:
                result = ipc.eval(line)
                print(result)
            except FoundationIPCError as e:
                print(f"Error: {e}")
    finally:
        ipc.disconnect()
    return 0


def cmd_eval(args):
    from ipc import FoundationIPC, FoundationIPCError
    try:
        with FoundationIPC(host=args.host, port=args.port) as ipc:
            result = ipc.eval(args.lua_code)
            print(result)
    except FoundationIPCError as e:
        print(f"Error: {e}")
        return 1
    return 0


def cmd_deploy_moddev(args):
    src = Path(__file__).resolve().parent / "moddev" / "init.lua"
    if not src.exists():
        src = Path(__file__).resolve().parent.parent / "moddev" / "init.lua"
    if not src.exists():
        print(f"moddev/init.lua not found (looked in src/moddev/ and moddev/)")
        return 1
    dest = Path(args.path) if args.path else (
        Path.home() / "Documents" / "Polymorph Games" / "Foundation" / "moddev" / "init.lua"
    )
    if dest.exists() and not args.force:
        print(f"Warning: {dest} already exists. Use --force to overwrite.")
        return 1
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(src.read_bytes())
    print(f"Deployed moddev/init.lua to {dest}")


def cmd_clone(args):
    src = Path(args.source)
    if not src.exists():
        print(f"Source not found: {src}")
        return 1
    sf = SaveFile.from_path(src)
    new_id = str(uuid.uuid4())
    stem = src.stem
    parts = stem.split("-", 1)
    if len(parts) > 1 and len(parts[0]) == 36 and parts[0].count("-") == 4:
        stem = parts[1]
    new_name = f"{new_id}-{stem}.foundation"
    if args.dest:
        dest = Path(args.dest)
        if dest.is_dir():
            dest = dest / new_name
    else:
        dest = src.parent / new_name
    dest.write_bytes(sf.to_bytes())
    print(f"Cloned save: {dest} ({dest.stat().st_size} bytes)")


def cmd_diff(args):
    a = SaveFile.from_path(Path(args.save_a))
    b = SaveFile.from_path(Path(args.save_b))
    ha = a.header_dict()
    hb = b.header_dict()
    print("=== Header Comparison ===")
    for key in ha:
        if ha[key] != hb[key]:
            print(f"  {key}: {ha[key]} vs {hb[key]}")
        else:
            print(f"  {key}: {ha[key]} (same)")
    print(f"\n=== Thumbnail ===")
    ah = hashlib.sha256(a.thumbnail).hexdigest()
    bh = hashlib.sha256(b.thumbnail).hexdigest()
    print(f"  A: {len(a.thumbnail)} bytes SHA256:{ah[:16]}...")
    print(f"  B: {len(b.thumbnail)} bytes SHA256:{bh[:16]}...")
    print(f"  Match: {ah == bh}")
    print(f"\n=== Binary Blob ===")
    ah = hashlib.sha256(a.blob).hexdigest()
    bh = hashlib.sha256(b.blob).hexdigest()
    print(f"  A: {len(a.blob)} bytes SHA256:{ah[:16]}...")
    print(f"  B: {len(b.blob)} bytes SHA256:{bh[:16]}...")
    if ah != bh:
        print(f"  Match: False")
        diffs = 0
        for i in range(min(len(a.blob), len(b.blob))):
            if a.blob[i] != b.blob[i]:
                print(f"  Diff at byte {i} (0x{i:x}): A=0x{a.blob[i]:02x} B=0x{b.blob[i]:02x}")
                diffs += 1
                if diffs >= 10:
                    print("  ... (showing first 10 diffs)")
                    break
        if len(a.blob) != len(b.blob):
            print(f"  Size differs: A={len(a.blob)} B={len(b.blob)}")
    else:
        print(f"  Match: True (blobs are identical)")
    return 0


def main():
    parser = argparse.ArgumentParser(
        description="CLI tool for Foundation (Steam App ID 690830) save files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  foundation-save-cli info save.foundation        Show save metadata
  foundation-save-cli thumbnail save.foundation    Extract thumbnail
  foundation-save-cli inject save.foundation thumb.png  Inject thumbnail
  foundation-save-cli connect                      Connect to running game
  foundation-save-cli eval "return level:getGame()"  Send Lua code
  foundation-save-cli clone save.foundation        Clone a save
  foundation-save-cli diff a.foundation b.foundation  Compare saves
        """,
    )

    sub = parser.add_subparsers(dest="command", metavar="<command>")

    p = sub.add_parser("info", help="Show metadata about a save file")
    p.add_argument("save_file", help="Path to .foundation save file")

    p = sub.add_parser("thumbnail", help="Extract thumbnail from a save file")
    p.add_argument("save_file", help="Path to .foundation save file")
    p.add_argument("-o", "--output", help="Output PNG path")

    p = sub.add_parser("inject", help="Inject a thumbnail PNG into a save file")
    p.add_argument("save_file", help="Path to .foundation save file")
    p.add_argument("png_file", help="Path to PNG thumbnail")
    p.add_argument("-o", "--output", help="Output .foundation path")

    p = sub.add_parser("connect", help="Connect to running Foundation game (TCP REPL)")
    p.add_argument("--host", default="127.0.0.1", help="TCP server host")
    p.add_argument("--port", type=int, default=27105, help="TCP server port")

    p = sub.add_parser("eval", help="Send Lua code to running Foundation game")
    p.add_argument("lua_code", help="Lua code to evaluate")
    p.add_argument("--host", default="127.0.0.1", help="TCP server host")
    p.add_argument("--port", type=int, default=27105, help="TCP server port")

    p = sub.add_parser("deploy-moddev", help="Copy moddev/init.lua to Foundation moddev folder")
    p.add_argument("--path", help="Target path for init.lua")
    p.add_argument("--force", action="store_true", help="Overwrite existing file")

    p = sub.add_parser("clone", help="Clone a save file with new UUID")
    p.add_argument("source", help="Source .foundation file")
    p.add_argument("dest", nargs="?", help="Destination path (default: auto-name in same dir)")

    p = sub.add_parser("diff", help="Compare two save files")
    p.add_argument("save_a", help="First save file")
    p.add_argument("save_b", help="Second save file")

    args = parser.parse_args()

    if args.command == "info":
        return cmd_info(args)
    elif args.command == "thumbnail":
        return cmd_thumbnail(args)
    elif args.command == "inject":
        return cmd_inject(args)
    elif args.command == "connect":
        return cmd_connect(args)
    elif args.command == "eval":
        return cmd_eval(args)
    elif args.command == "deploy-moddev":
        return cmd_deploy_moddev(args)
    elif args.command == "clone":
        return cmd_clone(args)
    elif args.command == "diff":
        return cmd_diff(args)
    else:
        parser.print_help()
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
