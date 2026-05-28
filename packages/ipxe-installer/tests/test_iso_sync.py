"""Tests for ipxe_installer.iso_sync (ISOSync)."""

import json
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
import requests
from ipxe_installer.iso_sync import ISOSync


@pytest.fixture
def syncer(tmp_path: Path) -> ISOSync:
    return ISOSync(
        repo="test/repo",
        release_tag="latest",
        output_dir=str(tmp_path / "output"),
        state_dir=str(tmp_path / "state"),
    )


class TestISOSync:
    def test_init_defaults(self, tmp_path: Path):
        s = ISOSync()
        assert s.repo == "Cairnstew/uup-dump-build-and-get-windows-iso"
        assert s.release_tag == "latest"
        assert s.output_dir == Path("/srv/pxe/windows")
        assert s.state_dir == Path("/var/lib/windows-iso-sync")

    def test_init_custom(self):
        s = ISOSync(
            repo="owner/custom",
            release_tag="v1.0",
            output_dir="/custom/output",
            state_dir="/custom/state",
            github_token="ghp_abc123",
        )
        assert s.repo == "owner/custom"
        assert s.github_token == "ghp_abc123"
        assert "Authorization" in s._session.headers

    def test_get_stored_tag_none(self, syncer: ISOSync):
        assert syncer._get_stored_tag() is None

    def test_get_stored_tag_exists(self, syncer: ISOSync):
        syncer.state_dir.mkdir(parents=True)
        (syncer.state_dir / ".last_tag").write_text("v1.0")
        assert syncer._get_stored_tag() == "v1.0"

    def test_write_stored_tag(self, syncer: ISOSync):
        syncer._write_stored_tag("v2.0")
        stamp = syncer.state_dir / ".last_tag"
        assert stamp.exists()
        assert stamp.read_text() == "v2.0"

    @patch("ipxe_installer.iso_sync.ISOSync._get_latest_release")
    def test_sync_already_up_to_date(self, mock_release, syncer: ISOSync):
        syncer.state_dir.mkdir(parents=True)
        (syncer.state_dir / ".last_tag").write_text("v1.0")
        mock_release.return_value = {"tag_name": "v1.0"}
        assert syncer.sync() is False

    @patch("ipxe_installer.iso_sync.ISOSync._get_latest_release")
    def test_sync_new_release(self, mock_release, syncer: ISOSync):
        mock_release.return_value = {
            "tag_name": "v1.0",
            "assets": [],
        }
        with patch.object(syncer, "_reassemble_iso", return_value=None):
            with pytest.raises(RuntimeError, match="No ISO found"):
                syncer.sync()

    @patch("ipxe_installer.iso_sync.requests.Session.get")
    def test_get_latest_release_success(self, mock_get):
        mock_resp = MagicMock()
        mock_resp.json.return_value = {"tag_name": "v1.0"}
        mock_get.return_value = mock_resp
        s = ISOSync(repo="test/repo", release_tag="latest")
        result = s._get_latest_release()
        assert result["tag_name"] == "v1.0"
        mock_get.assert_called_once()

    @patch("ipxe_installer.iso_sync.requests.Session.get")
    def test_get_latest_release_http_error(self, mock_get):
        mock_resp = MagicMock()
        mock_resp.raise_for_status.side_effect = requests.HTTPError("404")
        mock_get.return_value = mock_resp
        s = ISOSync(repo="test/repo")
        with pytest.raises(requests.HTTPError):
            s._get_latest_release()

    @patch("ipxe_installer.iso_sync.ISOSync._reassemble_iso")
    @patch("ipxe_installer.iso_sync.ISOSync._extract_boot_files")
    @patch("ipxe_installer.iso_sync.ISOSync._get_latest_release")
    def test_sync_full_flow(
        self, mock_release, mock_extract, mock_reassemble, syncer: ISOSync
    ):
        mock_release.return_value = {
            "tag_name": "v2.0",
            "assets": [{"name": "part1.7z.001", "browser_download_url": "https://example.com/part1"}],
        }
        mock_reassemble.return_value = Path("/fake/iso")

        with patch.object(syncer, "_download") as mock_download:
            result = syncer.sync()

        assert result is True
        mock_download.assert_called_once()
        mock_extract.assert_called_once_with(Path("/fake/iso"))
        assert (syncer.state_dir / ".last_tag").read_text() == "v2.0"

    def test_find_iso_none(self, tmp_path: Path):
        assert ISOSync._find_iso(tmp_path) is None

    def test_find_iso_found(self, tmp_path: Path):
        iso = tmp_path / "test.iso"
        iso.write_text("fake")
        result = ISOSync._find_iso(tmp_path)
        assert result == iso

    def test_find_iso_case_insensitive(self, tmp_path: Path):
        iso = tmp_path / "TEST.ISO"
        iso.write_text("fake")
        result = ISOSync._find_iso(tmp_path)
        assert result == iso
