{
  name = "_1password";
  description = "1Password desktop app, CLI, and SSH agent integration";
  category = "security";
  tags = [ "1password" "password-manager" "security" "ssh" ];
  # ssh-1password is also declared by home.nix — keep meta in sync
  provides = [ "my.programs._1password" "my.programs.ssh-1password" ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
  homepage = "https://1password.com";
}
