let
  config = import ../config.nix;
  users = [ config.me.sshKey ];

  laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICbrsmX987Oq4V3Kikiv/ogKoffdLKkibbmlrp+UytYS root@";
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ4fQUqAPiYzijmQjdpgdT7+yqd2O/ntJXmAiZsw63XO root@server";
  systems = [ server laptop ];
in
{ 
  # New ZeroNSD token secret
  "zeronsd-token.age".publicKeys = users ++ systems;
}
