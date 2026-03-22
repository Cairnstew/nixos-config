let
  config = import ../config.nix;
  users = [ config.me.sshKey ];

  laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETE96NnwPAZ0n5y6XcCzoErkrAhulUht/Hho0V829Qy root@laptop";
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINJXLC3S2pEuIchrWMtmWiTaJOA+U02HVyRczRNbRjMX root@nixos";
  wsl = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIW4gfFRLs6zBtHtWYSrkJ4oCSZ656CAt8oC/CAMVpCN root@DESKTOP-DLSTFLT";

  systems = [ laptop server wsl ];
in
{
  "zeronsd-token.age".publicKeys = users ++ systems;
  "spotify-cred.age".publicKeys = users ++ systems;
  "github-token.age".publicKeys = users ++ systems;
  "obsidian-git-token.age".publicKeys = users ++ systems;
  "nixos-config-git-token.age".publicKeys = users ++ systems;
  "nixos-config-cache-token.age".publicKeys = users ++ systems;
  "onepassword-token.age".publicKeys = users;
}
