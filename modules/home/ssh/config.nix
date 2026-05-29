{ config, lib, pkgs, flake, ... }:

let
  cfg = config.my.services.ssh;
  flakeSsh = flake.config.ssh or { };
in
{
  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = cfg.includes;

      extraConfig = lib.concatStringsSep "\n" (
        lib.optional cfg.addKeysToAgent "AddKeysToAgent yes"
        ++ lib.optional (cfg.identityAgent != null) "IdentityAgent ${cfg.identityAgent}"
        ++ lib.optional ((flakeSsh.serverAliveInterval or 0) != 0)
          "ServerAliveInterval ${toString (flakeSsh.serverAliveInterval or 60)}"
        ++ lib.optional (cfg.extraConfig != "") cfg.extraConfig
      );

      settings = lib.recursiveUpdate
        {
          "*" = {
            SendEnv = "LANG LC_*";
            HashKnownHosts = true;
          };
        }
        (lib.mapAttrs
          (_: block:
            block.extraOptions
            // lib.optionalAttrs (block.serverAliveInterval != null) {
              ServerAliveInterval = block.serverAliveInterval;
            }
            // lib.optionalAttrs (block.serverAliveCountMax != null) {
              ServerAliveCountMax = block.serverAliveCountMax;
            }
            // lib.optionalAttrs (block.host != "") { HostName = block.host; }
            // lib.optionalAttrs (block.user != "") { User = block.user; }
            // lib.optionalAttrs (block.port != null) { Port = block.port; }
            // lib.optionalAttrs (block.identityFile != null) { IdentityFile = block.identityFile; }
          )
          cfg.matchBlocks);
    };

    home.activation.generateSSHKey = lib.mkIf cfg.generateKey (
      config.lib.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f ${cfg.keyPath} ]; then
          mkdir -p $(dirname ${cfg.keyPath})
          ${pkgs.openssh}/bin/ssh-keygen \
            -t ${cfg.keyType} \
            -C "${cfg.email}" \
            -f ${cfg.keyPath} \
            -N ""
          echo "Generated new SSH key (${cfg.keyType}) for ${cfg.email}"
        fi
      ''
    );

    services.ssh-agent = lib.mkIf cfg.enableAgent { enable = true; };
  };
}
