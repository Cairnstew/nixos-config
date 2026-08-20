# Wires my.services.music into systemd oneshot services that build each enabled
# playlist as a fixed-output derivation and install it into a data dir —
# the "hashify songs like modpacks" pattern: songs.toml declares the playlist,
# checksums.json pins every song's URL + sha256, Nix builds/verifies the bytes.
{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf optionalAttrs;
  cfg = config.my.services.music;

  # Playlist declaration dir shipped with this module (the flake source in
  # /nix/store). Each subdir is a playlist: songs.toml + checksums.json.
  playlistsDir = ./playlists;

  # Enabled playlists (host opt-in by key), each with its resolved target dir.
  enabledPlaylists = lib.filterAttrs (_: pl: pl.enable) cfg.playlists;

  # Build one playlist's store content from its committed checksums.json.
  buildPlaylist = name:
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

  # One oneshot service per enabled playlist: build → rsync store → target.
  installServices = lib.mapAttrs'
    (name: pl:
      let
        built = buildPlaylist name;
        target = if pl.target != null then pl.target else "${cfg.dataDir}/${name}";
      in
      lib.nameValuePair "music-install-${name}" (optionalAttrs (built != null) {
        description = "Install music playlist ${name} into ${target}";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [ pkgs.rsync pkgs.coreutils ];
        script = ''
          set -euo pipefail
          SRC=${built}
          TARGET='${target}'
          mkdir -p "$TARGET"
          rsync -a --delete "$SRC/" "$TARGET/"
        '';
      }))
    enabledPlaylists;
in
mkIf cfg.enable {
  systemd.services = installServices;
}