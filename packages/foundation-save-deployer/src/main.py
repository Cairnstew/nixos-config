#!/usr/bin/env python3
import sys
import argparse
from pathlib import Path

from save_manager import SaveManager, find_save_path, colorize, GREEN, YELLOW, RED


def main():
    parser = argparse.ArgumentParser(
        description="Manage save files for Foundation (Steam App ID 690830)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  foundation-save-deployer path                     Show detected save path
  foundation-save-deployer list                     List all save files
  foundation-save-deployer backup                   Backup current saves
  foundation-save-deployer backup my_backup         Backup with custom name
  foundation-save-deployer restore my_backup        Restore from a backup
  foundation-save-deployer info                     Show latest save info
  foundation-save-deployer info my_city.foundation  Show specific save info
  foundation-save-deployer templates                List available templates
  foundation-save-deployer deploy quickstart        Deploy a template
  foundation-save-deployer template create starter  Create template from latest save
  foundation-save-deployer open                     Open save directory
        """,
    )
    parser.add_argument(
        "--path",
        help="Override save directory path (env: FOUNDATION_SAVE_PATH)",
        default=None,
    )

    sub = parser.add_subparsers(dest="command", metavar="<command>")
    sub.add_parser("path", help="Show the detected save path")
    sub.add_parser("open", help="Open the save directory in file manager")

    list_parser = sub.add_parser("list", help="List all save files with timestamps, sizes, and backup status")
    list_parser.add_argument("--json", action="store_true", help="Output as JSON")

    backup_parser = sub.add_parser("backup", help="Backup current saves")
    backup_parser.add_argument("name", nargs="?", help="Custom backup name")

    restore_parser = sub.add_parser("restore", help="Restore saves from a backup")
    restore_parser.add_argument("backup_name", help="Name of the backup to restore")

    info_parser = sub.add_parser("info", help="Show metadata about a save file")
    info_parser.add_argument("save_file", nargs="?", help="Save file name or path (default: latest)")

    sub.add_parser("templates", help="List available save templates")

    deploy_parser = sub.add_parser("deploy", help="Deploy a template to the save directory")
    deploy_parser.add_argument("template", help="Template name to deploy")

    create_parser = sub.add_parser("template", help="Create a template from an existing save")
    create_parser.add_argument("action", choices=["create"], help="Template action")
    create_parser.add_argument("name", help="Name for the new template")
    create_parser.add_argument("save_file", nargs="?", help="Source save file (default: latest)")

    args = parser.parse_args()

    mgr = SaveManager(save_path=Path(args.path) if args.path else find_save_path())

    if args.command == "path":
        return mgr.cmd_path()
    elif args.command == "open":
        return mgr.cmd_open()
    elif args.command == "list":
        if args.json:
            return json_list(mgr)
        return mgr.cmd_list()
    elif args.command == "backup":
        return mgr.cmd_backup(args.name)
    elif args.command == "restore":
        return mgr.cmd_restore(args.backup_name)
    elif args.command == "info":
        return mgr.cmd_info(args.save_file)
    elif args.command == "templates":
        return mgr.cmd_templates()
    elif args.command == "deploy":
        return mgr.cmd_deploy(args.template)
    elif args.command == "template":
        if args.action == "create":
            return mgr.cmd_create_template(args.name, args.save_file)
        print(f"{colorize(f'Unknown template action: {args.action}', RED)}")
        return 1
    else:
        parser.print_help()
        return 1


def json_list(mgr):
    import json
    from save_manager import scan_saves
    saves = scan_saves(mgr.save_path)
    data = []
    for s in saves:
        data.append({
            "name": s["name"],
            "size": s["size"],
            "mtime": s["mtime"].isoformat(),
        })
    json.dump(data, sys.stdout, indent=2)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
