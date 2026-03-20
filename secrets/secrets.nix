let
  config = import ../config.nix;
  users = [ config.me.sshKey ];

  laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETE96NnwPAZ0n5y6XcCzoErkrAhulUht/Hho0V829Qy root@laptop";
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINJXLC3S2pEuIchrWMtmWiTaJOA+U02HVyRczRNbRjMX root@nixos";
  wsl = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA2wdUAkZEY99Ya//2NcEY71ft3PaHoCQYOr2jIZf/99 root@nixos";

  systems = [ laptop server ];
in
{
  "zeronsd-token.age".publicKeys = [ systems wsl ];
  "zeronsd-token.age".armor = true;
  "spotify-cred.age".publicKeys = users ++ systems;
  "github-token.age".publicKeys = users ++ systems;
  "obsidian-git-token.age".publicKeys = users ++ systems;
}
