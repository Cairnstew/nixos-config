let
  config = import ../config.nix;
  users = [ config.me.sshKey ];

  laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOQ4JIoLFjDXNB2jtI3K41JzB5HCWk3aigRcXvtzJ7kO root@laptop";
  systems = [ laptop ];
in
{
  "zeronsd-token.age".publicKeys = [ server ];
  "zeronsd-token.age".armor = true;
  "spotify-cred.age".publicKeys = users ++ systems;
}
