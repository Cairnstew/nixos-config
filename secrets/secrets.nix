let
  config = import ../config.nix;
  users = [ config.me.sshKey ];

  laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICbrsmX987Oq4V3Kikiv/ogKoffdLKkibbmlrp+UytYS root@";
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKq0V2H7O6tl5ASJQBh7xCKLS4Pq12bPRTW0Zo5Dq1Is root@server";
  systems = [ server laptop ];
in
{ 
  # New ZeroNSD token secret
  "zeronsd-token.age".publicKeys = users ++ systems;
}
