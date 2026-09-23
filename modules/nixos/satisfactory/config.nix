{ config, lib, pkgs, ... }:
let
  cfg = config.my.programs.satisfactory;
in
{
  config = lib.mkIf cfg.enable {
    # ── Modding tools ──────────────────────────────────────────────────────
    environment.systemPackages = lib.optionals cfg.modding.enable [
      pkgs.ficsit-cli
      pkgs.satisfactorymodmanager
    ];

    # ── Dedicated server firewall ──────────────────────────────────────────
    networking.firewall = lib.mkIf cfg.dedicatedServer.enable {
      allowedUDPPorts = [
        cfg.dedicatedServer.gamePort
        cfg.dedicatedServer.queryPort
        cfg.dedicatedServer.beaconPort
      ];
    };
  };
}
