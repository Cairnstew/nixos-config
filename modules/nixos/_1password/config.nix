{ config, lib, flake, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.programs._1password;
in
{
  config = mkIf cfg.enable {
    # The CLI (with its setgid wrapper) is useful on every host, including
    # headless ones.
    programs._1password.enable = true;

    # The Electron app, polkit integration and SSH agent socket only make
    # sense where a graphical session runs — default to the workstation
    # profile, which reflects that.
    programs._1password-gui = mkIf cfg.gui.enable {
      enable = true;
      polkitPolicyOwners = [ "${flake.config.me.username}" ];
    };
    security.polkit.enable = mkIf cfg.gui.enable true;

    home-manager.users.${flake.config.me.username} = {
      imports = [ ./home.nix ];
      my.programs.ssh-1password = {
        # ~/.1password/agent.sock only exists while the app is running.
        enable = cfg.gui.enable;
        # programs._1password already installs the CLI via the setgid wrapper
        # that can reach the app-integration socket. The home-profile copy has
        # no group access and only shadows it.
        install1PasswordCli = false;
      };
    };
  };
}
