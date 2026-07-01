{ flake, pkgs, lib, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  nixpkgs = {
    config = {
      allowBroken = true;
      allowUnsupportedSystem = true;
      allowUnfree = true;
    };
    overlays = lib.attrValues self.overlays;
  };

  nix = {
    # Choose from https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=nix
    # package = pkgs.nixVersions.latest;

    nixPath = [ "nixpkgs=${flake.inputs.nixpkgs}" ]; # Enables use of `nix-shell -p ...` etc
    registry = {
      nixpkgs.flake = flake.inputs.nixpkgs; # Make `nix shell` etc use pinned nixpkgs
      nixpkgs-unstable.flake = flake.inputs.nixpkgs-unstable;
    };

    daemonCPUSchedPolicy = "batch";
    daemonIOSchedPriority = 7;

    settings = {
      max-jobs = 4;
      cores = 0;
      min-free = lib.mkDefault (5 * 1024 * 1024 * 1024);
      max-free = lib.mkDefault (30 * 1024 * 1024 * 1024);
      auto-optimise-store = true;
      experimental-features = "nix-command flakes";
      # I don't have an Intel mac.
      extra-platforms = lib.mkIf pkgs.stdenv.isDarwin "aarch64-darwin x86_64-darwin";
      # Nullify the registry for purity.
      flake-registry = builtins.toFile "empty-flake-registry.json" ''{"flakes":[],"version":2}'';
      trusted-users = [ "root" (if pkgs.stdenv.isDarwin then flake.config.me.username else "@wheel") ];
    };
  };
}
