# Music — hash-pinned playlist downloads ("hashify songs like modpacks")

Downloads playlists declared in this repo as reproducible, byte-pinned songs —
the same pattern the Minecraft modpacks use. A playlist is a directory that
declares its songs in `songs.toml` and pins every download in a committed
`checksums.json`; Nix builds each song as a fixed-output derivation and a
systemd service installs them into your data dir.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.music.enable` | `false` | Enable playlist install services |
| `my.services.music.dataDir` | `/mnt/media/Music` | Base install dir |
| `my.services.music.playlists.<name>.enable` | `false` | Install this playlist |
| `my.services.music.playlists.<name>.target` | `''${dataDir}/<name>` | Override install dir |

## Usage Example

```nix
my.services.music = {
  enable = true;
  dataDir = "/mnt/media/Music";
  playlists.chill.enable = true;
};
```

## Adding / updating a playlist

1. Create `modules/nixos/music/playlists/<name>/songs.toml`:

   ```toml
   name = "Chill"
   source = "direct"   # "direct" (byte-stable URL) or "yt-dlp" (YouTube, best-effort)

   [[songs]]
   key = "focus-01"
   url = "https://archive.org/download/some-item/focus-01.mp3"
   # source = "yt-dlp" songs also accept:
   # format = "ba[ext=m4a]"
   # extractorArgs = "youtube:player_client=web_safari"
   ```

2. `git add` the new files, then regenerate the pin file:
   `nix run .#music-checksums-<name>` (downloads + sha256-hashes each song).
   Commit `checksums.json`.
3. Rebuild the host (`nix run .#activate` or `just deploy-run <host>`); the
   `music-install-<name>` oneshot rsyncs the built store dir into the target.

## Notes

- **Two source tiers.** `direct` sources (archive.org, jamendo, any stable
  direct URL) are byte-stable forever and behave exactly like mod jars.
  `yt-dlp` sources (YouTube, Spotify…) are **best-effort**: the pinned sha256
  verifies the bytes at build time, but if the source re-encodes you must
  re-run `music-checksums-<name>` and commit a new `checksums.json` (the build
  fails loudly with a hash mismatch — not silently).
- **Gotcha — checksums before `git add` silently skips new songs.** The check
  app runs inside a flake snapshot, so it only sees git-tracked files. Always
  `git add` songs.toml changes before regenerating checksums.json.
- Playlist keys must be enabled per-host (`playlists.<name>.enable`) — the
  declared dirs in the repo are inert until a host opts in.