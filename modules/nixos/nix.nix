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
      # ventoy versions are flagged insecure due to binary blobs (nixpkgs#404663).
      # Derive the names from the packages so a nixpkgs version bump (e.g.
      # 1.1.12 → 1.1.17) can't leave the list stale and break the system build.
      permittedInsecurePackages = map (p: p.name) (with pkgs; [
        ventoy
        ventoy-full
        ventoy-full-qt
        ventoy-full-gtk
      ]);
    };
    overlays = lib.attrValues self.overlays;
  };

  nix = {
    # Choose from https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=nix
    # package = pkgs.nixVersions.latest;

    nixPath = [ "nixpkgs=${flake.inputs.nixpkgs}" ]; # Enables use of `nix-shell -p ...` etc
    registry = {
      nixpkgs.flake = flake.inputs.nixpkgs; # Make `nix shell` etc use pinned nixpkgs
      nixpkgs-unstable.flake = flake.inputs.nixpkgs; # nixpkgs-unstable removed as input — same branch as nixpkgs (M5)
    };

    daemonCPUSchedPolicy = "batch";
    daemonIOSchedPriority = 7;

    settings = {
      max-jobs = 4;
      cores = 0;
      min-free = lib.mkDefault (5 * 1024 * 1024 * 1024);
      # max-free is the free-space *ceiling* at which the daemon starts
      # deleting store paths, NOT a "keep this much spare" target (that is
      # min-free). Setting it to 30 GiB on a 379G disk meant that with 73 GiB
      # actually free the auto-GC ran continuously, deleting freshly-built
      # paths that were valid in the Nix DB but not yet referenced by a
      # finished derivation. The symptom is a build failing on a path Nix
      # insists is fine:
      #   error: getting attributes of path "/nix/store/...-foo": No such file
      # while `nix-store --realise <path>` still exits 0. See GOTCHAS.md.
      # 100 GiB keeps the store bounded without firing on every rebuild;
      # delete this line entirely if an unbounded store is preferred.
      max-free = lib.mkDefault (100 * 1024 * 1024 * 1024);
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      # I don't have an Intel mac.
      extra-platforms = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "aarch64-darwin x86_64-darwin";
      # Nullify the registry for purity.
      flake-registry = builtins.toFile "empty-flake-registry.json" ''{"flakes":[],"version":2}'';
      trusted-users = [ "root" (if pkgs.stdenv.hostPlatform.isDarwin then flake.config.me.username else "@wheel") ];
    };
  };
}
