{pkgs, config, flake, ...}:
{
  programs.ssh = {
    enable = true;
    
    # Generate a new SSH key if it doesn't exist
    extraConfig = ''
      AddKeysToAgent yes
    '';
  };

  # Generate SSH key on activation if it doesn't exist
  home.activation.generateSSHKey = config.lib.dag.entryAfter ["writeBoundary"] ''
    if [ ! -f ~/.ssh/id_ed25519 ]; then
      mkdir -p ~/.ssh
      ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -C "${flake.config.me.email}" -f ~/.ssh/id_ed25519 -N ""
      echo "Generated new SSH key for ${flake.config.me.email}"
    fi
  '';

  #services.ssh-agent = lib.mkIf pkgs.stdenv.isLinux { enable = true; };
}