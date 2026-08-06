{
  name = "caches";
  description = "Per-host binary cache (substituter) configuration with optional periodic Cachix push via systemd timers";
  category = "system";
  tags = [ "nix" "cache" "cachix" "substituter" "systemd" ];
  provides = [ "my.caches" ];
  # Defaults are inherited from the flake-level my.caches config
  # (flake.config.my.caches); push tokenFiles are wired from agenix secrets.
  expects = [ "flake.config.my.caches" "agenix-manager" ];
  complexity = "medium";
  # New file: never claim test coverage until tests.nix is wired into default.nix.
  tested = false;
  maintainer = "seanc";
}
