# Wires my.services.minecraftServer into services.minecraft-servers (nix-minecraft).
{ config, lib, flake, ... }:

let
  inherit (lib) mkIf mapAttrs' nameValuePair concatStringsSep;
  inherit (flake) inputs;
  inherit (inputs) nix-minecraft;

  cfg = config.my.services.minecraftServer;

  # Runtime symlinks for a modpack content dir, created via extraStartPre so
  # the pack stays a plain path on disk (no Nix-store copy for 800 MB+ packs).
  # Directories are symlinked only if they exist at service start — placing the
  # pack later needs no rebuild.
  packStartPre = srv:
    if srv.pack == null then ""
    else
      let
        subdirs = [ "mods" "config" "kubejs" "scripts" "datapacks" "defaultconfigs" ];
      in
      concatStringsSep "\n" (builtins.map
        (d: ''
          if [ -d "${srv.pack}/${d}" ]; then
            ln -sfn "${srv.pack}/${d}" "${d}"
          fi
        '')
        subdirs);

  mkServer = name: srv:
    nameValuePair name {
      inherit (srv)
        package
        jvmOpts
        serverProperties
        whitelist
        operators
        openFirewall
        restart
        managementSystem
        ;
      extraStartPre = packStartPre srv;
    };

in
{
  imports = [
    nix-minecraft.nixosModules.minecraft-servers
  ];

  config = mkIf cfg.enable {
    # nix-minecraft's overlay provides vanillaServers/fabricServers/neoforgeServers/…
    nixpkgs.overlays = [ nix-minecraft.overlay ];

    services.minecraft-servers = {
      enable = true;
      inherit (cfg) eula dataDir openFirewall;
      servers = mapAttrs' mkServer cfg.servers;
    };
  };
}
