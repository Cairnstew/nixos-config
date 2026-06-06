{ config, lib, pkgs, ... }:
let
  cfg = config.my.deploy;
  liveCfg = config.my.live.isos.deploy or { };
in
{
  # ── L0: Nix assertions ──────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !cfg.enable || (config.my.live.isos ? deploy);
      message = "my.deploy.enable is true but my.live.isos.deploy is not configured. Ensure the live-iso module is imported (it is part of nixosModules.common).";
    }
  ];

  # ── L1: Deploy ISO config validation (runtime) ──────────────────────────────
  systemd.services.deploy-validation = lib.mkIf cfg.enable {
    description = "Validate deploy ISO configuration";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    serviceConfig.ExecStart = pkgs.writeShellScript "deploy-validation" ''
      set -euo pipefail
      echo "=== Validating Deploy Configuration ==="

      if [ "${builtins.toString liveCfg.tailscale.authKeyEncryptedSource or null}" != "" ]; then
        echo "PASS: authKeyEncryptedSource is set"
      else
        echo "WARN: authKeyEncryptedSource is null — deploy ISO will not have tailscale auto-auth"
      fi

      if [ -f "${builtins.toString liveCfg.tailscale.authKeyFile or ""}" ] || [ "${builtins.toString liveCfg.tailscale.authKeyFile or ""}" = "" ]; then
        echo "INFO: authKeyFile is set to ${builtins.toString liveCfg.tailscale.authKeyFile or "(default)"}"
      fi

      echo "=== Deploy Validation Complete ==="
    '';
  };
}
