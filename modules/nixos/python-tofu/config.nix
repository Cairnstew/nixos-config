# modules/nixos/python-tofu/config.nix
# Host-local wiring for the upstream python-tofu flake module.
#
# The option surface stays upstream (`services.python-tofu.*`); this file only
# translates the curated `my.services.python-tofu.*` options onto it and wires
# the agenix credential.
{ config, lib, ... }:

let
  cfg = config.my.services.python-tofu;

  agenixPrefix = "/run/agenix/";
  credentialsPath = cfg.credentialsFile;

  # AGENTS.md §6.4: never reference a secret without the existence guard.
  # An agenix path is exported only when that secret is declared on this host;
  # any other path (sops, systemd credentials) is passed through as written.
  isAgenixPath =
    credentialsPath != null && lib.hasPrefix agenixPrefix credentialsPath;
  secretName =
    if credentialsPath == null then "" else lib.removePrefix agenixPrefix credentialsPath;
  hasSecret =
    isAgenixPath && builtins.hasAttr secretName (config.age.secrets or { });

  credentialsAvailable =
    credentialsPath != null && (!isAgenixPath || hasSecret);
in
{
  config = lib.mkIf cfg.enable {
    services.python-tofu = {
      enable = true;

      # Upstream evaluates/merges these at build time and rejects a
      # simultaneous `settings.config`, so pass them through unchanged.
      inherit (cfg) stack stackFile;

      environment = lib.mkIf credentialsAvailable {
        GOOGLE_APPLICATION_CREDENTIALS = credentialsPath;
      };
    } // lib.optionalAttrs cfg.applyOnRebuild {
      settings = {
        command = "apply";
        autoApprove = true;
      };
    };
  };
}
