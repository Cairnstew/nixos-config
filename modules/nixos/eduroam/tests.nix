# eduroam tests — L0 assertions
{ config, lib, ... }:
let
  cfg = config.my.networking.eduroam;
in
{
  config = lib.mkIf cfg.enable {
    # ── L0: Nix assertions ────────────────────────────────────────────────────
    # NetworkManager is the only supported connection manager for this module.
    assertions = [
      {
        assertion = config.networking.networkmanager.enable;
        message = "my.networking.eduroam requires networking.networkmanager.enable = true";
      }
      # The whole point of the module is to auto-authenticate without manual
      # password entry; an empty identity string would break EAP.
      {
        assertion = cfg.identity != "";
        message = "my.networking.eduroam.identity must not be empty";
      }
    ];
  };
}
