{
  name = "core";
  description = "Core home-manager configuration — git, nix settings, and agenix secrets";
  category = "core";
  tags = [ "home" "core" "git" "nix" "agenix" ];
  # T7: options.my.programs.core does not exist (grep-verified) — list what
  # core actually sets (git.nix: programs.git/delta/lazygit + home.packages;
  # nix.nix: home.sessionPath; agenix.nix: age.identityPaths).
  provides = [ "programs.git" "programs.delta" "programs.lazygit" "home.packages" "home.sessionPath" "age.identityPaths" ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
}
