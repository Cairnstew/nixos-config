let
  config = import ../config.nix;
  users = [ config.me.sshKey ];

  laptop = "";
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ4fQUqAPiYzijmQjdpgdT7+yqd2O/ntJXmAiZsw63XO root@server";
  systems = [ server ];
in
{ 
  #"hedgedoc.env.age".publicKeys = users ++ systems;
  #"github-nix-ci/srid.token.age".publicKeys = users ++ systems;
  #"pureintent-basic-auth.age".publicKeys = users ++ systems;

  # New ZeroNSD token secret
  "zeronsd-token.age".publicKeys = users ++ systems;
}
