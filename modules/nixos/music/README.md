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

## Creating a playlist from a PUBLIC Spotify playlist

Make the Spotify playlist **public once** (temporarily is fine — the committed
`songs.toml`/`checksums.json` stay the truth after), then from the repo root:

```sh
nix run .#music-spotify-sync -- <name> https://open.spotify.com/playlist/<id>
#   fetch tracks (no user OAuth — client-credentials reads public playlists)
#   → each track resolved to a YouTube URL via yt-dlp (ISRC first)
#   → writes songs.toml (keys = Spotify track ids) → regenerates checksums.json
git commit -m "music: sync <name> from Spotify"
```

Re-sync is incremental: existing songs (matched by Spotify key) keep their
URL + hash byte-identical; only new tracks are resolved. `--prune` drops songs
no longer upstream. No server-side OAuth needed — only private playlists /
Liked Songs would require one (and then a Spotify API app secret).

## Adding / updating a playlist by hand

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
- **Spotify sync credentials.** `music-spotify-sync` defaults to spotdl's
  bundled public client credentials (enough for public playlists, but shared,
  so rate-limited). For reliable syncsing set `SPOTIFY_CLIENT_ID` /
  `SPOTIFY_CLIENT_SECRET` from your own free Spotify API app.