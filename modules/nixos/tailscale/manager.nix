{ config, lib, flake, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.services.tailscale.manager;
  sec = config.my.secrets;
  oauthKey = sec.catalog."tailscale.oauthKey" or null;
  hasOauth = sec.enable && oauthKey != null && oauthKey.file or null != null;
  oauthKeyName = oauthKey.name or "tailscale-oauthkey";
in
{
  config = mkIf cfg.enable {
    services.tailscale-manager = {
      enable = true;
      tailnet = cfg.tailnet;
      tags = cfg.tags;
      acl.enable = cfg.acl.enable;
      providerVersion = cfg.providerVersion;
      credentialsFile = "/run/agenix/${oauthKeyName}";
      policy = {
        enable = cfg.policy.enable;
        tagOwners = cfg.policy.tagOwners;
        grants =
          # Prepend inter-node grants from interNodePorts
          (map (port: {
            src = [ "tag:nixos" ];
            dst = [ "tag:nixos" ];
            ip = [ port ];
          }) cfg.policy.interNodePorts)
          ++ cfg.policy.grants;
        ssh = cfg.policy.ssh;
        acls = cfg.policy.acls;
      } // cfg.policy.extraConfig;
    };

    age.secrets = lib.optionalAttrs hasOauth {
      ${oauthKeyName} = {
        file = oauthKey.file;
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };
  };
}
