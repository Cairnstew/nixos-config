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
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/lib/types/settings.ts \
        --replace-fail 'http://localhost:4567' '${cfg.serverUrl}'
      substituteInPlace src/lib/core/auth.ts \
        --replace-fail 'http://127.0.0.1:4567' '${cfg.serverUrl}'
      substituteInPlace src/hooks.client.ts \
        --replace-fail 'http://127.0.0.1:4567' '${cfg.serverUrl}'
      substituteInPlace src/lib/state/boot.svelte.ts \
        --replace-fail 'http://127.0.0.1:4567' '${cfg.serverUrl}'
      substituteInPlace src/lib/server-adapters/suwayomi/index.ts \
        --replace-fail 'http://127.0.0.1:4567' '${cfg.serverUrl}'
    '';
  });
in
{
  options.my.programs.moku = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Moku — Tauri manga reader frontend for Suwayomi-Server";
    };

    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:4567";
      example = "http://server:4567";
      description = "Default Suwayomi server URL baked into the Moku build. The user can still override in Settings > General > Server URL.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      mokuPackage
    ];
  };
}
