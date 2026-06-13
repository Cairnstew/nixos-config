{ config, lib, pkgs, flake, ... }:

let
  cfg = config.my.programs.moku;
  inherit (flake) inputs;

  mokuPackage = inputs.moku.packages.${pkgs.system}.moku.overrideAttrs (old: {
    pnpmDeps = pkgs.fetchPnpmDeps {
      pname = "moku";
      version = old.version;
      src = old.src;
      fetcherVersion = 3;
      # Updated from build output: sha256-fBkNpQXEeGZNbrpx7+0xVYYtQ6dGvpgRflCGPoxvnVY=
      hash = "sha256-fBkNpQXEeGZNbrpx7+0xVYYtQ6dGvpgRflCGPoxvnVY=";
    };
  });
in
{
  options.my.programs.moku = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Moku — Tauri manga reader frontend for Suwayomi-Server";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      mokuPackage
    ];
  };
}
