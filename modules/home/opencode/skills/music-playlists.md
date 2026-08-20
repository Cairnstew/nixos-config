# Music Playlists (hash-pinned downloads)

> Skill for adding/updating hash-pinned music playlists in this repo — "hashify songs like modpacks". Playlists are declared in git, pinned in a committed `checksums.json`, built as fixed-output derivations, and installed into a data dir.

## Overview

The music module (`modules/nixos/music/`) reuses the packwiz modpack hashing pattern for audio downloads: a playlist directory declares its songs (`songs.toml`) and pins every download URL + sha256 in a committed `checksums.json`; Nix builds each song as a **fixed-output derivation** and a per-host systemd oneshot installs the built store dir into your data dir. Metadata lives in git; the bytes are verified at build time.

- Playlist dirs: `modules/nixos/music/playlists/<name>/`
- Options (declared in `modules/nixos/music/options.nix`):
  - `my.services.music.enable` (default `false`) — enable install services
  - `my.services.music.dataDir` (default `/mnt/media/Music`) — base install dir
  - `my.services.music.playlists.<name>.enable` — install this playlist
  - `my.services.music.playlists.<name>.target` — override install dir

## Playlist directory layout

```
modules/nixos/music/playlists/<name>/
├── songs.toml        # declaration: name, source, [[songs]] (key, url, format?)
└── checksums.json    # generated + committed: { "<key>": { url, sha256 } }
```

`songs.toml` example (`modules/nixos/music/playlists/example/songs.toml`):

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

## The two source tiers (important)

- **`source = "direct"`** (archive.org, jamendo, any byte-stable URL): built with
  `pkgs.fetchurl` — fully deterministic, no runtime network. Behaves exactly like a mod jar.
- **`source = "yt-dlp"`** (YouTube, …): **best-effort**. Built as a fixed-output
  derivation that runs `yt-dlp` *inside* the build (FOD builds are allowed network); the
  committed sha256 pins the exact bytes. If the source re-encodes or changes, the build
  **fails loudly with a hash mismatch** — not silently — and you must regenerate.

## Adding / updating a playlist

Run these from the repo root (flake snapshot only sees git-tracked files):

1. Create the playlist dir + `songs.toml` (see layout above).
2. **`git add` the new/changed `songs.toml` FIRST** — the checksums app runs inside a
   flake snapshot, so untracked song declarations are silently invisible. This is the
   #1 gotcha.
3. Regenerate the pin file: `nix run .#music-checksums-<name>`
   (downloads + sha256-hashes each song at runtime, writes + `git add`s `checksums.json`).
4. Verify the pinned bytes build: `nix build .#music-playlist-<name>`
5. Install without a full system rebuild: `nix run .#music-install-<name> -- [target]`
   (target defaults to `${dataDir}/<name>`).
6. Or enable per-host and let the install service do it: set
   `my.services.music.playlists.<name>.enable = true;` in the host config and rebuild
   (`nix run .#activate` or `just deploy-run <host>`).

## Flake outputs (modules/flake-parts/music.nix)

Auto-wired per playlist directory (a new playlist dir automatically gets these):

| Output | Purpose |
|--------|---------|
| `packages."music-playlist-<name>"` | Built playlist dir (every song as FOD) |
| `apps."music-checksums-<name>"` | Regenerates `<playlist>/checksums.json` |
| `apps."music-install-<name>"` | Build + rsync into a target dir without a rebuild |

The shared builder lives at `modules/nixos/music/playlist-builder.nix` and is consumed
both by the flake outputs and the NixOS install services.

## Notes

- A declared playlist dir is **inert until a host opts in** via
  `playlists.<name>.enable = true` — the repo dirs by themselves install nothing.
- If a `yt-dlp` build fails with a hash mismatch, re-run
  `music-checksums-<name>` and commit the new `checksums.json` — don't just delete the
  pin or loosen the FOD hash.