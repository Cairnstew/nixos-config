{pkgs, config, flake, ...}:
{
  # Enable the OpenSSH daemon
  services.openssh.enable = true;

  # Generate root SSH key if it doesn't exist
  system.activationScripts.generateRootSSHKey = ''
    if [ ! -f /root/.ssh/id_ed25519 ]; then
      mkdir -p /root/.ssh
      ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -C "root@$(hostname)" -f /root/.ssh/id_ed25519 -N ""
      echo "Generated new SSH key for root user"
    fi
  '';
}