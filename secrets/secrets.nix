let
  config = import ../config.nix;
  users = [ config.me.sshKey ];

  laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETE96NnwPAZ0n5y6XcCzoErkrAhulUht/Hho0V829Qy root@laptop";
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINJXLC3S2pEuIchrWMtmWiTaJOA+U02HVyRczRNbRjMX root@nixos";
  wsl = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIW4gfFRLs6zBtHtWYSrkJ4oCSZ656CAt8oC/CAMVpCN root@DESKTOP-DLSTFLT";

  systems = [ laptop server wsl ];
  all = users ++ systems;
in
{
  "zeronsd-token.age".publicKeys = all;
  "spotify-cred.age".publicKeys = all;
  "github-token.age".publicKeys = all;
  "obsidian-git-token.age".publicKeys = all;
  "nixos-config-git-token.age".publicKeys = all;
  "nixos-config-cache-token.age".publicKeys = all;
  "zt-ssh-key.age".publicKeys = all;

  # Tailscale Keys - Expire after 90 Days - Created : 3/23/2026
  "tailscale-authkey.age".publicKeys = all;
  "tailscale-apikey.age".publicKeys = all;
  "tailscale-ssh-key.age".publicKeys = all;

  # OnePass Key
  "onepassword-token.age".publicKeys = users;
}
