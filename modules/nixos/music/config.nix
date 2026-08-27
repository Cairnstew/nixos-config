# Wires my.services.music into systemd oneshot services that install each
# enabled playlist into a data dir — the "hashify songs like modpacks" pattern.
#
# Two tiers, chosen by the playlist's `source` in songs.toml:
#   - `direct`  : byte-stable URL (archive.org, jamendo, …). Built as a Nix
#                 fixed-output derivation (pkgs.fetchurl) and rsynced into the
#                 target — fully reproducible, no runtime network.
#   - `yt-dlp`  : YouTube/Spotify. Runs the runtime installer OUTSIDE the Nix
#                 build sandbox; the sandboxed FOD build cannot work here
#                 (no DNS in the sandbox + YouTube anti-bot on datacenter IPs).
#                 The committed checksums.json is the source of truth: the
#                 installer verifies each downloaded file's sha256 against the
#                 pin and hard-fails on mismatch.
{ config, lib, pkgs, flake, ... }:

let
  inherit (lib) mkIf;
  cfg = config.my.services.music;

  # Playlist declaration dir shipped with this module (the flake source in
  # /nix/store). Each subdir is a playlist: songs.toml + checksums.json.
  playlistsDir = ./playlists;

  # Runtime yt-dlp installer (must live in the flake source so it reads the
  # committed checksums.json of the resolved playlist dir).
  runtimeInstaller = "${flake.inputs.self}/modules/flake-parts/music-install.py";

  # Enabled playlists (host opt-in by key), each with its resolved target dir.
  enabledPlaylists = lib.filterAttrs (_: pl: pl.enable) cfg.playlists;

  # Read a playlist's `source` (default "direct").
  playlistSource = name:
    let
      st = "${playlistsDir}/${name}/songs.toml";
    in
    if builtins.pathExists st then
      (builtins.fromTOML (builtins.readFile st)).source or "direct"
    else
      "direct";

  # `direct` tier: build the playlist as a fixed-output derivation.
  buildPlaylistFod = name:
    let
      playlistDir = "${playlistsDir}/${name}";
      haveChecksums = builtins.pathExists "${playlistDir}/checksums.json";
    in
    if !haveChecksums then
      lib.warn ''
        my.services.music: playlist ${name} is enabled but has no
        checksums.json yet. Write songs.toml, `git add` it, then run
        `nix run .#music-checksums-${name}` and commit checksums.json.
        Skipping install for now.
      ''
        null
    else
      import ./playlist-builder.nix {
        inherit pkgs lib name playlistDir;
      };

  # One oneshot service per enabled playlist. yt-dlp installs are LONG (a
  # first-run download can take hours), so they must NOT be pulled into the
  # multi-user.target transaction: `start multi-user.target` during any
  # nixos-rebuild switch would wait on the download and make the activation
  # unit appear hung. The installer runs detached (not wanted by the target)
  # and an instant `music-install-<name>-kick` unit starts it with
  # `systemctl start --no-block`, so boot still installs but never blocks.
  # `direct` tier installs are seconds (FOD rsync), so they stay inline.
  installServices = builtins.listToAttrs (lib.flatten (lib.mapAttrsToList
    (name: pl:
      let
        target = if pl.target != null then pl.target else "${cfg.dataDir}/${name}";
        source = playlistSource name;
        isYtdlp = source == "yt-dlp";
        fod = if isYtdlp then null else buildPlaylistFod name;
        base = {
          description = "Install music playlist ${name} into ${target}";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [ pkgs.rsync pkgs.coreutils pkgs.python3 pkgs.yt-dlp ];
        };
      in
      lib.optionals (isYtdlp || fod != null) (
        if isYtdlp then [
          (lib.nameValuePair "music-install-${name}" (base // {
            script = ''
              set -euo pipefail
              export PATH='${pkgs.yt-dlp}/bin':$PATH
              # systemd does not set TMPDIR for services, so fall back to /tmp
              # (the Nix-build copy in playlist-builder.nix can keep $TMPDIR).
              export HOME="''${TMPDIR:-/tmp}"
              TARGET='${target}'
              mkdir -p "$TARGET"
              ${pkgs.python3}/bin/python3 ${runtimeInstaller} '${playlistsDir}/${name}' "$TARGET"
            '';
          }))
          (lib.nameValuePair "music-install-${name}-kick" {
            description = "Kick detached music install ${name}";
            wantedBy = [ "multi-user.target" ];
            after = [ "local-fs.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              set -euo pipefail
              # Detached: the install runs in the background and never blocks
              # multi-user.target (a switch must not wait on a download).
              systemctl start --no-block 'music-install-${name}.service' || true
            '';
          })
        ] else [
          (lib.nameValuePair "music-install-${name}" (base // {
            wantedBy = [ "multi-user.target" ];
            after = [ "local-fs.target" ];
            script = ''
              set -euo pipefail
              SRC=${fod}
              TARGET='${target}'
              mkdir -p "$TARGET"
              rsync -a --delete "$SRC/" "$TARGET/"
            '';
          }))
        ]
      ))
    enabledPlaylists));
in
mkIf cfg.enable {
  systemd.services = installServices;
}
