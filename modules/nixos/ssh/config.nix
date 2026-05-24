{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.ssh;
in
{
  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };

    users.users.root.openssh.authorizedKeys.keys = cfg.authorizedKeys;

    system.activationScripts.generateRootSSHKey = ''
      if [ ! -f /root/.ssh/id_ed25519 ]; then
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -C "root@$(hostname)" -f /root/.ssh/id_ed25519 -N ""
        echo "Generated new SSH key for root"
      fi
    '';
  };
}
