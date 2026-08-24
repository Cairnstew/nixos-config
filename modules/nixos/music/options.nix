{ lib, ... }:

let
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.my.services.music = {
    enable = mkEnableOption "hash-pinned music playlist downloads (my.services.music)";

    dataDir = mkOption {
      type = types.str;
      default = "/mnt/media/Music";
      description = ''
        Base directory playlists are installed into. Each enabled playlist
        lands in <literal>''${dataDir}/&lt;name&gt;</literal> unless it overrides
        <literal>target</literal>. Keep this on a large/secondary drive (e.g.
        <literal>/mnt/media/Music</literal>) so songs never fill the system disk.
      '';
    };

    playlists = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkEnableOption "this playlist";
          target = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Directory to install this playlist into. Defaults to
              <literal>''${dataDir}/&lt;playlist-name&gt;</literal>.
            '';
          };
        };
      });
      default = { };
      description = ''
        Playlists to install. Keys must match directories under
        <literal>modules/nixos/music/playlists/</literal>. Each playlist dir
        declares its songs in <literal>songs.toml</literal> and pins their
        download hashes in its committed <literal>checksums.json</literal>
        (regenerated with <literal>nix run .#music-checksums-&lt;name&gt;</literal>).
        Only playlists listed here (with <literal>enable = true</literal>) are
        installed; the rest are inert declarations in the repo.
      '';
    };
  };
}
