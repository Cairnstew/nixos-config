{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.gh;
in
{
  config = lib.mkIf cfg.enable {
    # ── L0: Nix assertions ────────────────────────────────────────────────────
    assertions = [
      {
        assertion = cfg.tokenFile != null -> builtins.isString cfg.tokenFile;
        message = "my.programs.gh.tokenFile must be a string path if set.";
      }
    ];
  };
}
