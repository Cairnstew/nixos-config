# Make flake.config.peope.myself the admin of the machine
{ flake, pkgs, lib, ... }:

{
  # Login via SSH with mmy SSH key
  users.users =
    let
      me = flake.config.me;
      myKeys = [
        me.sshKey

      ];
    in
    {
      root.openssh.authorizedKeys.keys = myKeys;
      ${me.username} = {
        openssh.authorizedKeys.keys = myKeys;
        shell = pkgs.zsh;
      } // lib.optionalAttrs pkgs.stdenv.isLinux {
        isNormalUser = true;
        extraGroups = [ "networkmanager" "wheel" ];
      };
    };

  programs.zsh.enable = lib.mkIf pkgs.stdenv.isLinux true;

  # Make me a sudoer without password
  security = lib.optionalAttrs pkgs.stdenv.isLinux {
    sudo.execWheelOnly = true;
    sudo.wheelNeedsPassword = false;
  };

  # ── L0: Security assertions ──────────────────────────────────────────────
  assertions = [
    {
      assertion = lib.stringLength (flake.config.me.sshKey or "") > 0;
      message = "flake.config.me.sshKey must be a non-empty string for admin SSH access.";
    }
    {
      assertion = lib.stringLength (flake.config.me.username or "") > 0;
      message = "flake.config.me.username must be a non-empty string for admin user creation.";
    }
  ];
}
