{ pkgs, config, lib, ... }:
{
  options.my.services.ssh = {
    enable = lib.mkEnableOption "SSH daemon with auto-generated root key";

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "SSH public keys authorized for root login.";
    };
  };

  config = lib.mkIf config.my.services.ssh.enable {

    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };

    users.users.root.openssh.authorizedKeys.keys = config.my.services.ssh.authorizedKeys;

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