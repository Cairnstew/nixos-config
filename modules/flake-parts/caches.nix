{ lib, config, ... }:

let
  inherit (import ../nixos/caches/cache-type.nix { inherit lib; }) cacheOpts mkSubstituters mkPublicKeys;
in
{
  options.my.caches = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule cacheOpts);
    default = { };
    description = ''
      Binary caches (substituters) used by this flake.

      Each attribute is a named cache. Caches are sorted by priority
      (lower = first) when building the substituter list.

      To disable a cache on a specific host:
        my.caches.nixos-cuda.enable = false;

      To add a custom cache:
        my.caches.my-cache = {
          substituter = "https://my-cache.cachix.org";
          publicKey = "my-cache.cachix.org-1:abc123...";
        };

      To enable pushing to a cache:
        my.caches.personal.push.enable = true;
        my.caches.personal.push.tokenFile =
          config.age.secrets.nixos-config-cache-token.path;
    '';
    example = lib.literalExpression ''
      {
        nixos = {
          enable = true;
          substituter = "https://cache.nixos.org/";
          publicKey = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
        };
      }
    '';
  };

  config = {
    # Default caches (mirrors the old hardcoded nixConfig in flake.nix)
    my.caches = {
      nixos = {
        enable = true;
        substituter = "https://cache.nixos.org/";
        publicKey = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
        priority = 20;
      };
      nixos-cuda = {
        enable = true;
        substituter = "https://cache.nixos-cuda.org/";
        publicKey = "cache.nixos-cuda.org-1:dykfIgNYfi2cKCfb4xMBbOjlzFnEiCsHxlXLjfXDwOY=";
        priority = 10;
      };
      nix-community = {
        enable = true;
        substituter = "https://nix-community.cachix.org";
        publicKey = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
        priority = 30;
      };
      personal = {
        enable = true;
        substituter = "https://cairnstew-nixos-config-cache.cachix.org";
        publicKey = "cairnstew-nixos-config-cache.cachix.org-1:1150paajFeK18p7Eie/4L8iews3pbFbVp3eOxkmXar4=";
        priority = 40;
      };
    };

    # Flake-level nixConfig (affects nix build / nix develop on this flake)
    flake.nixConfig = {
      substituters = mkSubstituters config.my.caches;
      trusted-public-keys = mkPublicKeys config.my.caches;
    };
  };
}
