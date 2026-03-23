{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkEnableOption mkOption mkIf mkDefault types literalExpression;

  cfg = config.my.services.tailscale;

in
{
  # ── Options ────────────────────────────────────────────────────────────────
  options.my.services.tailscale = {
    enable = mkEnableOption "Tailscale mesh VPN";

    authKeySecretFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to the agenix-encrypted .age file containing the Tailscale
        auth key (tskey-auth-xxx). The module declares age.secrets automatically.
      '';
      example = literalExpression "flake.inputs.self + /secrets/tailscale-authkey.age";
    };

    apiKeySecretFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to the agenix-encrypted .age file containing the Tailscale
        API key. Used by the apply-tailscale-policy script.
      '';
      example = literalExpression "flake.inputs.self + /secrets/tailscale-apikey.age";
    };

    policyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to a JSON file containing the Tailscale tailnet policy
        (grants, tags, SSH rules). Applied via the apply-tailscale-policy script.
      '';
      example = literalExpression "flake.inputs.self + /tailscale-policy.json";
    };

    tags = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "tag:nixos" "tag:server" ];
      description = "Tailscale tags to advertise for this machine.";
    };

    exitNode = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to advertise this machine as a Tailscale exit node.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the Tailscale UDP port in the firewall.";
    };
  };

  # ── Implementation ─────────────────────────────────────────────────────────
  config = mkIf cfg.enable {

    # Auto-declare age.secrets for the auth key.
    age.secrets."tailscale-authkey" = mkIf (cfg.authKeySecretFile != null) {
      file  = cfg.authKeySecretFile;
      owner = "root";
      mode  = "0400";
    };

    # Auto-declare age.secrets for the API key.
    age.secrets."tailscale-apikey" = mkIf (cfg.apiKeySecretFile != null) {
      file  = cfg.apiKeySecretFile;
      owner = "root";
      mode  = "0400";
    };

    services.tailscale = {
      enable      = true;
      openFirewall = cfg.openFirewall;
      authKeyFile = mkIf (cfg.authKeySecretFile != null)
        config.age.secrets."tailscale-authkey".path;
      extraUpFlags =
        (lib.optional (cfg.tags != [])
          "--advertise-tags=${lib.concatStringsSep "," cfg.tags}")
        ++ (lib.optional cfg.exitNode "--advertise-exit-node");
    };

    # Trusted interface so LAN traffic flows freely over Tailscale.
    networking.firewall.trustedInterfaces = [ "tailscale0" ];

    # Script to push the policy file to Tailscale via the API.
    environment.systemPackages = lib.optional
      (cfg.apiKeySecretFile != null && cfg.policyFile != null)
      (pkgs.writeShellScriptBin "apply-tailscale-policy" ''
        set -euo pipefail
        API_KEY=$(cat ${config.age.secrets."tailscale-apikey".path})
        echo "Applying Tailscale policy from ${cfg.policyFile}..."
        curl -s -X POST https://api.tailscale.com/api/v2/tailnet/-/acl \
          -H "Authorization: Bearer $API_KEY" \
          -H "Content-Type: application/json" \
          -d @${cfg.policyFile}
        echo "Done."
      '');
  };
}
