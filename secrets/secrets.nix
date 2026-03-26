let
  config = import ../config.nix;
  users = [ config.me.sshKey ];

  laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETE96NnwPAZ0n5y6XcCzoErkrAhulUht/Hho0V829Qy root@laptop";
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINJXLC3S2pEuIchrWMtmWiTaJOA+U02HVyRczRNbRjMX root@nixos";
  wsl = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAKZIYbM8ac+hHEAvvScLq2lHtAHi44Zlvlew/QYU3H0 root@wsl";

  systems = [ laptop server wsl ];
  all = users ++ systems;
in
{
  # Overall GitHub Token
  "github-token.age".publicKeys = all;

  # Git Repos
  "github-token-nixos-config.age".publicKeys = all;
  "github-token-obsidian.age".publicKeys = all;

  # Cache Token
  "nixos-config-cache-token.age".publicKeys = all;

  # Tailscale Keys - Expire after 90 Days - Created : 3/23/2026
  "tailscale-authkey.age".publicKeys = all;
  "tailscale-apikey.age".publicKeys = all;
  "tailscale-ssh-key.age".publicKeys = all;

  # OnePass Key
  "onepassword-token.age".publicKeys = users;
}
