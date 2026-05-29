{ lib, pkgs, rootAuthorizedKey, ... }: {
  image.baseName = lib.mkForce "nixos-installer";

  nix.extraOptions = "experimental-features = nix-command flakes";

  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = "/iso/ts.key";
  };

  services.openssh = {
    enable = true;
    hostKeys = [ ];
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "prohibit-password";
  };

  users.users.root.openssh.authorizedKeys.keys = [ (lib.trim rootAuthorizedKey) ];

  boot.postBootCommands = ''
    cp /iso/ssh_host_ed25519_key /etc/ssh/
    chmod 400 /etc/ssh/ssh_host_ed25519_key
    cp /iso/ssh_host_ed25519_key.pub /etc/ssh/
  '';
}
