import os
import shutil
import stat
import json
import glob
import datetime
import textwrap
import subprocess
from pathlib import Path


GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
CYAN = "\033[96m"
BOLD = "\033[1m"
RESET = "\033[0m"


def colorize(text, color):
    return f"{color}{text}{RESET}"


BACKUP_DIR = Path.home() / ".local" / "share" / "foundation-save-deployer" / "backups"
TEMPLATES_DIR = Path.home() / ".local" / "share" / "foundation-save-deployer" / "templates"
STEAM_SAVE_REL = "steamapps/compatdata/690830/pfx/drive_c/users/steamuser/Documents/Polymorph Games/Foundation/Save Game"


def find_steam_libraries():
    libraries = []
    common = [
        Path.home() / ".steam" / "steam",
        Path.home() / ".local" / "share" / "Steam",
    ]
    for p in common:
        if p.exists():
            libraries.append(p)
    try:
        with open("/proc/mounts") as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 2:
                    mount = parts[1]
                    if mount.startswith("/mnt/") or mount.startswith("/media/"):
                        for candidate in [
                            Path(mount) / "SteamLibrary",
                            Path(mount) / "steam_library",
                            Path(mount) / "Steam",
                            Path(mount) / "steam",
                        ]:
                            if candidate.exists() and candidate not in libraries:
                                libraries.append(candidate)
    except OSError:
        pass
    return libraries


def find_save_path():
    env_path = os.environ.get("FOUNDATION_SAVE_PATH")
    if env_path:
        p = Path(env_path)
        if p.exists():
            return p
    libraries = find_steam_libraries()
    for lib in libraries:
        candidate = lib / STEAM_SAVE_REL
        if candidate.exists():
            return candidate
    return None


def human_size(num):
    for unit in ("B", "KB", "MB", "GB"):
        if num < 1024:
            return f"{num:.1f} {unit}"
        num /= 1024
    return f"{num:.1f} TB"


def format_timestamp(ts):
    return ts.strftime("%Y-%m-%d %H:%M")


def scan_saves(save_path):
    if not save_path or not save_path.exists():
        return []
    saves = []
    for f in sorted(save_path.iterdir()):
        if f.is_file() and f.suffix.lower() in (".foundation",):
            mtime = datetime.datetime.fromtimestamp(f.stat().st_mtime)
            saves.append({
                "name": f.name,
                "path": f,
                "size": f.stat().st_size,
                "mtime": mtime,
            })
    return saves


def get_backup_list():
    if not BACKUP_DIR.exists():
        return []
    backups = []
    for d in sorted(BACKUP_DIR.iterdir()):
        if d.is_dir():
            backups.append({
                "name": d.name,
                "path": d,
                "size": sum(
                    f.stat().st_size for f in d.rglob("*") if f.is_file()
                ),
                "mtime": datetime.datetime.fromtimestamp(d.stat().st_mtime),
                "count": len(list(d.glob("*.foundation"))),
            })
    return backups


def get_template_list():
    templates = []
    if TEMPLATES_DIR.exists():
        for f in sorted(TEMPLATES_DIR.iterdir()):
            if f.is_file() and f.suffix.lower() in (".foundation",):
                templates.append({
                    "name": f.stem,
                    "path": f,
                    "size": f.stat().st_size,
                    "mtime": datetime.datetime.fromtimestamp(f.stat().st_mtime),
                })
    return templates


class SaveManager:
    def __init__(self, save_path=None):
        self.save_path = save_path or find_save_path()
        self.backup_dir = BACKUP_DIR
        self.templates_dir = TEMPLATES_DIR

    def cmd_path(self):
        if self.save_path:
            print(f"Found Foundation saves at: {colorize(str(self.save_path), CYAN)}")
        else:
            print(f"{colorize('Save path not found. Set FOUNDATION_SAVE_PATH env var or use --path.', RED)}")
            return 1
        return 0

    def cmd_open(self):
        if self.save_path and self.save_path.exists():
            subprocess.run(["xdg-open", str(self.save_path)])
            print(f"{colorize('Opened:', GREEN)} {self.save_path}")
        else:
            print(f"{colorize('Save directory not found.', RED)}")
            return 1
        return 0

    def cmd_list(self):
        if not self.save_path or not self.save_path.exists():
            print(f"{colorize('Save directory not found.', RED)}")
            return 1
        saves = scan_saves(self.save_path)
        if not saves:
            print(f"{colorize('No save files found.', YELLOW)}")
            return 0
        backups = {b["name"] for b in get_backup_list()}
        print(f"{colorize('Save files for Foundation:', BOLD)}")
        for i, s in enumerate(saves, 1):
            backed_up = backups and any(s["name"] in str(b) for b in BACKUP_DIR.rglob(s["name"]))
            backup_mark = f" {colorize('[backed up]', GREEN)}" if backed_up else ""
            print(
                f"  [{i}] {s['name']:40s} {format_timestamp(s['mtime']):16s} {human_size(s['size']):>8s}{backup_mark}"
            )
        return 0

    def cmd_backup(self, name=None):
        if not self.save_path or not self.save_path.exists():
            print(f"{colorize('Save directory not found.', RED)}")
            return 1
        saves = scan_saves(self.save_path)
        if not saves:
            print(f"{colorize('No save files found to backup.', YELLOW)}")
            return 0
        if name:
            backup_name = name
        else:
            backup_name = f"foundation-saves-{datetime.datetime.now().strftime('%Y-%m-%d-%H%M%S')}"
        dest = self.backup_dir / backup_name
        dest.mkdir(parents=True, exist_ok=True)
        for s in saves:
            shutil.copy2(str(s["path"]), str(dest / s["name"]))
        print(f"{colorize('Backup created:', GREEN)} {backup_name}")
        print(f"  Location: {dest}")
        print(f"  Files: {len(saves)}")
        return 0

    def cmd_restore(self, backup_name):
        backups = get_backup_list()
        matches = [b for b in backups if b["name"] == backup_name]
        if not matches:
            print(f"{colorize(f'Backup not found: {backup_name}', RED)}")
            return 1
        backup = matches[0]
        if not self.save_path:
            print(f"{colorize('Save directory not found. Cannot restore.', RED)}")
            return 1
        files = list(backup["path"].glob("*.foundation"))
        for f in files:
            shutil.copy2(str(f), str(self.save_path / f.name))
        print(f"{colorize(f'Restored {len(files)} saves from backup:', GREEN)} {backup_name}")
        return 0

    def cmd_info(self, save_file=None):
        if not self.save_path or not self.save_path.exists():
            print(f"{colorize('Save directory not found.', RED)}")
            return 1
        if save_file:
            target = Path(save_file)
            if not target.is_absolute():
                target = self.save_path / target
        else:
            saves = scan_saves(self.save_path)
            if not saves:
                print(f"{colorize('No save files found.', YELLOW)}")
                return 0
            target = saves[-1]["path"]
        if not target.exists():
            print(f"{colorize(f'File not found: {target}', RED)}")
            return 1
        st = target.stat()
        mtime = datetime.datetime.fromtimestamp(st.st_mtime)
        steam_cloud = self._check_steam_cloud(target.name)
        backup_exists = any(target.name in str(b) for b in BACKUP_DIR.rglob(target.name))
        print(f"{colorize('Save File Info:', BOLD)}")
        print(f"  Name:       {target.name}")
        print(f"  Path:       {target}")
        print(f"  Size:       {human_size(st.st_size)} ({st.st_size} bytes)")
        print(f"  Modified:   {format_timestamp(mtime)}")
        print(f"  Steam Cloud: {colorize('synced', GREEN) if steam_cloud else colorize('not synced', YELLOW)}")
        print(f"  Backed up:  {colorize('yes', GREEN) if backup_exists else colorize('no', YELLOW)}")
        return 0

    def cmd_templates(self):
        templates = get_template_list()
        if not templates:
            print(f"{colorize('No templates found.', YELLOW)}")
            print(f"  Template directory: {self.templates_dir}")
            return 0
        print(f"{colorize('Available templates:', BOLD)}")
        for i, t in enumerate(templates, 1):
            print(
                f"  [{i}] {t['name']:40s} {format_timestamp(t['mtime']):16s} {human_size(t['size']):>8s}"
            )
        print(f"\n  Use {colorize('deploy <template>', CYAN)} to copy a template to the save directory.")
        return 0

    def cmd_deploy(self, template_name):
        templates = get_template_list()
        matches = [t for t in templates if t["name"] == template_name]
        if not matches:
            print(f"{colorize(f'Template not found: {template_name}', RED)}")
            print(f"  Available templates: {[t['name'] for t in templates]}")
            return 1
        template = matches[0]
        if not self.save_path:
            print(f"{colorize('Save directory not found. Cannot deploy.', RED)}")
            return 1
        self.save_path.mkdir(parents=True, exist_ok=True)
        dest = self.save_path / template["path"].name
        shutil.copy2(str(template["path"]), str(dest))
        name = template["path"].name
        print(f"{colorize(f'Deployed template {name!r} to save directory', GREEN)}")
        print(f"  {dest}")
        return 0

    def cmd_create_template(self, name, save_file=None):
        if not self.save_path or not self.save_path.exists():
            print(f"{colorize('Save directory not found.', RED)}")
            return 1
        if save_file:
            src = Path(save_file)
            if not src.is_absolute():
                src = self.save_path / src
        else:
            saves = scan_saves(self.save_path)
            if not saves:
                print(f"{colorize('No save files found. Specify a save file.', YELLOW)}")
                return 1
            src = saves[-1]["path"]
        if not src.exists():
            print(f"{colorize(f'Source file not found: {src}', RED)}")
            return 1
        self.templates_dir.mkdir(parents=True, exist_ok=True)
        dest = self.templates_dir / f"{name}.foundation"
        shutil.copy2(str(src), str(dest))
        print(f"{colorize(f'Template created:', GREEN)} {name}")
        print(f"  Source: {src}")
        print(f"  Destination: {dest}")
        return 0

    def _check_steam_cloud(self, filename):
        if not self.save_path:
            return False
        cloud_dir = self.save_path.parent.parent / ".cloud"
        if cloud_dir.exists():
            for f in cloud_dir.rglob(filename):
                return True
        return False
