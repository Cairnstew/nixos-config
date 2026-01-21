let
  config = import ../config.nix;
  users = [ config.me.sshKey ];

  laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICbrsmX987Oq4V3Kikiv/ogKoffdLKkibbmlrp+UytYS root@";
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILxKH++jNeehzeT6oKkNMtIIaWUF8aKeQ4pDg5FC7uBI root@server";
  systems = [ server laptop ];
in
{
  "zeronsd-token.age".publicKeys = [ server ];
  "zeronsd-token.age".armor = true;
  "spotify-cred.age".publicKeys = systems;
}
