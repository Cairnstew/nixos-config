"""Windows ISO sync — download, reassemble, extract boot files."""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Optional

import requests

GITHUB_API = "https://api.github.com/repos"
DEFAULT_REPO = "Cairnstew/uup-dump-build-and-get-windows-iso"


class ISOSync:
    """Download Windows ISO from GitHub releases, reassemble, extract boot files."""

    def __init__(
        self,
        repo: str = DEFAULT_REPO,
        release_tag: str = "latest",
        output_dir: str = "/srv/pxe/windows",
        state_dir: str = "/var/lib/windows-iso-sync",
        github_token: str = "",
    ):
        self.repo = repo
        self.release_tag = release_tag
        self.output_dir = Path(output_dir)
        self.state_dir = Path(state_dir)
        self.github_token = github_token
        self._session = requests.Session()
        if github_token:
            self._session.headers.update({"Authorization": f"token {github_token}"})

    # ── GitHub API ──

    def _get_latest_release(self) -> dict:
        """Fetch release info from GitHub API."""
        if self.release_tag == "latest":
            url = f"{GITHUB_API}/{self.repo}/releases/latest"
        else:
            url = f"{GITHUB_API}/{self.repo}/releases/tags/{self.release_tag}"

        resp = self._session.get(url)
        resp.raise_for_status()
        return resp.json()

    def _get_stored_tag(self) -> Optional[str]:
        """Read the last synced tag from stamp file."""
        stamp = self.state_dir / ".last_tag"
        if stamp.exists():
            return stamp.read_text().strip()
        return None

    def _write_stored_tag(self, tag: str) -> None:
        """Write the synced tag to stamp file."""
        self.state_dir.mkdir(parents=True, exist_ok=True)
        (self.state_dir / ".last_tag").write_text(tag)

    # ── Download and reassembly ──

    def sync(self) -> bool:
        """Sync Windows ISO — download, reassemble, extract.

        Returns True if boot files were updated, False if already current.
        """
        release = self._get_latest_release()
        tag = release["tag_name"]

        stored = self._get_stored_tag()
        if stored == tag:
            return False

        with tempfile.TemporaryDirectory(prefix="iso-sync-") as tmpdir:
            tmp = Path(tmpdir)

            # Download all assets
            assets = release.get("assets", [])
            for asset in assets:
                url = asset["browser_download_url"]
                name = asset["name"]
                dest = tmp / name
                self._download(url, dest)

            # Reassemble ISO
            iso_path = self._reassemble_iso(tmp)
            if not iso_path:
                raise RuntimeError("No ISO found after reassembly")

            # Mount and extract
            self._extract_boot_files(iso_path)

        self._write_stored_tag(tag)
        return True

    def _download(self, url: str, dest: Path) -> None:
        """Download a file with progress."""
        resp = self._session.get(url, stream=True)
        resp.raise_for_status()
        total = int(resp.headers.get("content-length", 0))
        downloaded = 0
        with open(dest, "wb") as f:
            for chunk in resp.iter_content(chunk_size=8192):
                f.write(chunk)
                downloaded += len(chunk)

    def _reassemble_iso(self, tmpdir: Path) -> Optional[Path]:
        """Reassemble ISO from split archive files.

        Tries: reassemble.sh → 7z → cat → raw .iso
        """
        # Method A: Run reassemble.sh
        reassemble = tmpdir / "reassemble.sh"
        if reassemble.exists():
            os.chmod(reassemble, 0o755)
            subprocess.run(["bash", str(reassemble)], cwd=tmpdir, capture_output=True)
            iso = self._find_iso(tmpdir)
            if iso:
                return iso

        # Method B: 7z extraction
        parts_7z = sorted(tmpdir.glob("*.7z.001"))
        parts_zip = sorted(tmpdir.glob("*.zip.001"))
        if parts_7z or parts_zip:
            part = parts_7z[0] if parts_7z else parts_zip[0]
            subprocess.run(
                ["7z", "x", "-y", str(part)],
                cwd=tmpdir,
                capture_output=True,
            )
            iso = self._find_iso(tmpdir)
            if iso:
                return iso

        # Method C: Concatenation
        parts = sorted(tmpdir.glob("*.part*")) + sorted(tmpdir.glob("*.iso.*"))
        if parts:
            combined = tmpdir / "combined.iso"
            with open(combined, "wb") as out:
                for p in parts:
                    out.write(p.read_bytes())
            return combined

        # Method D: Raw ISO
        return self._find_iso(tmpdir)

    @staticmethod
    def _find_iso(dirpath: Path) -> Optional[Path]:
        """Find an ISO file (case-insensitive)."""
        for p in dirpath.iterdir():
            if p.suffix.upper() == ".ISO":
                return p
        return None

    # ── Boot file extraction ──

    def _extract_boot_files(self, iso_path: Path) -> None:
        """Mount ISO and extract boot files for PXE."""
        with tempfile.TemporaryDirectory(prefix="iso-mnt-") as mntdir:
            # Mount via loop
            result = subprocess.run(
                ["losetup", "--show", "-f", "-P", str(iso_path)],
                capture_output=True, text=True,
            )
            loop_dev = result.stdout.strip()
            try:
                subprocess.run(
                    ["mount", "-o", "loop,ro", loop_dev, mntdir],
                    check=True, capture_output=True,
                )
                mnt = Path(mntdir)

                self.output_dir.mkdir(parents=True, exist_ok=True)

                # bootmgfw.efi
                src = mnt / "bootmgfw.efi"
                if src.exists():
                    shutil.copy2(str(src), str(self.output_dir / "bootmgfw.efi"))

                # boot/ subdir
                boot_dir = self.output_dir / "boot"
                boot_dir.mkdir(parents=True, exist_ok=True)

                for fname in ["boot/bcd", "boot/boot.sdi"]:
                    src = mnt / fname
                    if src.exists():
                        shutil.copy2(str(src), str(self.output_dir / fname))

                # sources/boot.wim
                sources_dir = self.output_dir / "sources"
                sources_dir.mkdir(parents=True, exist_ok=True)
                wim = mnt / "sources" / "boot.wim"
                if wim.exists():
                    shutil.copy2(str(wim), str(sources_dir / "boot.wim"))
                else:
                    raise FileNotFoundError("sources/boot.wim not found on ISO")

            finally:
                subprocess.run(["umount", mntdir], capture_output=True)
                subprocess.run(["losetup", "-d", loop_dev], capture_output=True)
