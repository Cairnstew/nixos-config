let
  config = import ../config.nix;
  users = [ config.me.sshKey ];

  laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOQ4JIoLFjDXNB2jtI3K41JzB5HCWk3aigRcXvtzJ7kO root@laptop";
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINJXLC3S2pEuIchrWMtmWiTaJOA+U02HVyRczRNbRjMX root@nixos";

  systems = [ laptop server ];
in
{
  "zeronsd-token.age".publicKeys = [ systems ];
  "zeronsd-token.age".armor = true;
  "spotify-cred.age".publicKeys = users ++ systems;
  "github-token.age".publicKeys = users ++ systems;
}
