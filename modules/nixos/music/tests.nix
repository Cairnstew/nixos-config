{ config, lib, ... }:

let
  cfg = config.my.services.music;
  playlistsDir = ./playlists;
  discovered =
    builtins.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir playlistsDir));
  enabledPlaylists = lib.filterAttrs (_: pl: pl.enable) cfg.playlists;
in
{
  # ── L0: Nix assertions ────────────────────────────────────────────────────
  assertions = [
    {
      # Enabling music without any playlist is almost certainly a mistake.
      assertion = !(cfg.enable && cfg.playlists == { });
      message = "my.services.music is enabled but no playlists are enabled. Set my.services.music.playlists.<name>.enable = true for playlists under modules/nixos/music/playlists/.";
    }
    {
      # Playlist keys must match directories in the module's playlists/ dir.
      assertion = builtins.all (k: builtins.elem k discovered) (builtins.attrNames cfg.playlists);
      message = "my.services.music: unknown playlist key(s). Discovered playlists: ${lib.concatStringsSep ", " discovered}";
    }
    {
      # dataDir must be an absolute path (systemd and rsync need it).
      assertion = !cfg.enable || lib.hasPrefix "/" cfg.dataDir;
      message = "my.services.music.dataDir must be an absolute path (got '${cfg.dataDir}')";
    }
  ];

  # ── L2: Smoke-test oneshot ───────────────────────────────────────────────
  # Triggers every playlist install service and verifies each target dir
  # contains at least one file. Run manually:
  #   systemctl start music-smoke-test
  systemd.services.music-smoke-test = lib.mkIf cfg.enable {
    description = "Smoke test for music playlists";
    after = map (n: "music-install-${n}.service") (builtins.attrNames enabledPlaylists);
    serviceConfig.Type = "oneshot";
    script = lib.concatStringsSep "\n" (lib.mapAttrsToList
      (name: pl:
        let
          target = if pl.target != null then pl.target else "${cfg.dataDir}/${name}";
        in
        ''
          if [ ! -d '${target}' ] || [ -z "$(ls -A '${target}')" ]; then
            echo "FAIL: ${name} target ${target} missing or empty (run: systemctl start music-install-${name})" >&2
            exit 1
          fi
          echo "PASS: ${name} -> ${target}"
        '')
      enabledPlaylists);
  };
}