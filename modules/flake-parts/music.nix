# =============================================================================
# music.nix — hash-pinned music playlist tooling at the flake level
# =============================================================================
# Purpose: Expose the "hashify songs like modpacks" workflow. Playlists live
#          in modules/nixos/music/playlists/<name>/ (declaration songs.toml +
#          generated checksums.json) and are turned into Nix fixed-output
#          derivations exactly like packwiz2nix turns a modpack into FODs.
#
# Outputs (perSystem):
#   - packages."music-playlist-<name>" → built playlist dir (every song FOD)
#   - apps."music-checksums-<name>"    → regenerates <playlist>/checksums.json
#   - apps."music-install-<name>"      → build + install into a target dir
#                                        WITHOUT a full system rebuild
#
# Usage:
#   cd modules/nixos/music/playlists/<name>
#   # 1. write songs.toml (declaration)
#   # 2. git add songs.toml  (flakes only snapshot tracked files)
#   nix run .#music-checksums-<name>   # download + hash → checksums.json
#   git add checksums.json
#   nix build .#music-playlist-<name>  # verify the pinned bytes build
#   nix run .#music-install-<name> -- /mnt/media/Music/<name>  # copy to disk
#
# The checksum app downloads and hashes every song at RUNTIME (when `nix run`
# runs it) rather than at eval or build time — the downloader (yt-dlp) needs
# network — and writes checksums.json back into the live working tree, exactly
# like packwiz-checksums.nix does for modpacks.
# =============================================================================

{ config, inputs, lib, ... }:
let
  inherit (lib) concatMap;
  inherit (inputs) self;

  # Directory holding music playlists (one subdir per playlist). Read at eval
  # time so a new playlist directory automatically gets a checksums app and
  # package. Only subdirectories count.
  playlistsDir = "${self}/modules/nixos/music/playlists";
  playlistNames =
    if builtins.pathExists playlistsDir then
      builtins.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir playlistsDir))
    else
      [ ];

  checksumsScript = ./music-checksums.py;

  # Shared "hashify" builder wired to a specific playlist dir.
  buildPlaylist = pkgs: name:
    import ../nixos/music/playlist-builder.nix {
      inherit pkgs lib;
      playlistDir = "${playlistsDir}/${name}";
      inherit name;
    };

  # App that regenerates <playlist>/checksums.json in the LIVE working tree.
  # Must run from the repo root (like modpack-update). New songs.toml changes
  # must be `git add`ed first or the flake snapshot won't include them.
  mkChecksumsApp = pkgs: name:
    let
      script = pkgs.writeShellScriptBin "music-checksums-${name}" ''
        set -euo pipefail
        if [ ! -f flake.nix ]; then
          echo "music-checksums-${name}: run this from the repo root" >&2
          exit 1
        fi
        P="$PWD/modules/nixos/music/playlists/${name}"
        if [ ! -d "$P" ]; then
          echo "music-checksums-${name}: no playlist dir at $P" >&2
          exit 1
        fi
        export PATH=${pkgs.yt-dlp}/bin:$PATH
        ${pkgs.python3}/bin/python3 ${checksumsScript} "$P"
        git add "$P/checksums.json"
      '';
    in
    {
      type = "app";
      program = "${script}/bin/music-checksums-${name}";
    };

  # App: build the playlist package and install it into a target dir without a
  # system rebuild. Usage: nix run .#music-install-<name> -- [target]
  # target defaults to ${config.music.dataDir}/<name> (flake config) or
  # /mnt/media/Music/<name>.
  mkInstallApp = pkgs: name:
    let
      pkg = buildPlaylist pkgs name;
      defaultTarget =
        (config.music.dataDir or "/mnt/media/Music") + "/" + name;
      script = pkgs.writeShellScriptBin "music-install-${name}" ''
        set -euo pipefail
        export PATH=${pkgs.rsync}/bin:${pkgs.coreutils}/bin:$PATH
        TARGET=''${1:-${defaultTarget}}
        SRC="${pkg}"
        echo "music-install-${name}: ${pkg} -> $TARGET"
        mkdir -p "$TARGET"
        rsync -a --delete "$SRC/" "$TARGET/"
        echo "music-install-${name}: done"
      '';
    in
    {
      type = "app";
      program = "${script}/bin/music-install-${name}";
    };
in
{
  perSystem = { pkgs, ... }: {
    packages = lib.listToAttrs (map
      (name: lib.nameValuePair "music-playlist-${name}" (buildPlaylist pkgs name))
      playlistNames);

    apps = lib.listToAttrs (concatMap
      (name: [
        (lib.nameValuePair "music-checksums-${name}" (mkChecksumsApp pkgs name))
        (lib.nameValuePair "music-install-${name}" (mkInstallApp pkgs name))
      ])
      playlistNames);
  };
}