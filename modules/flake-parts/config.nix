# Top-level configuration for everything in this repo.
#
# Values are set in 'config.nix' in repo root.
{ lib, ... }:
let
  userSubmodule = lib.types.submodule {
    options = {
      username = lib.mkOption {
        type = lib.types.str;
      };
      fullname = lib.mkOption {
        type = lib.types.str;
      };
      email = lib.mkOption {
        type = lib.types.str;
      };
      sshKey = lib.mkOption {
        type = lib.types.str;
        description = ''
          SSH public key
        '';
      };
      zerotier_token = lib.mkOption {
        type = lib.types.str;
        description = ''
          Zerotier Admin Token, for Zeronsd
        '';
      };

      # ✅ Add this for ZeroTier network IDs
      zerotier_networks = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          List of ZeroTier network IDs to join (e.g. ["8056c2e21c000001" "1234567890abcdef"]).
        '';
        example = [ "8056c2e21c000001" "1234567890abcdef" ];
      };
    };
  };
in
{
  imports = [
    ../../config.nix
  ];

  options = {
    me = lib.mkOption {
      type = userSubmodule;
    };
  };
}
