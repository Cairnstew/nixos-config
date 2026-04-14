{ flake, config, lib, pkgs, ... }:

let
  inherit (lib)
    mkOption mkEnableOption mkIf mkMerge
    types mapAttrs mapAttrsToList attrNames;

  cfg  = config.my.secrets;
  me   = flake.config.me.username;
  self = flake.inputs.self;

  # ── Secret catalogue ────────────────────────────────────────────────────────
  # Each entry:  "<option-path>" = { name, file, extra? }
  #   option-path  – dot-separated path under options.my.secrets (used to build
  #                  the nested option AND the cfg accessor)
  #   name         – the agenix / age.secrets key
  #   file         – default .age file relative to flake root (or null)
  #   extra        – optional age.secrets overrides (owner, group, mode…)
  secretDefs = {
    "tailscale.authKey"    = { name = "tailscale-authkey";            file = self + /secrets/tailscale/authkey.age;            extra = {};                         };
    "tailscale.apiKey"     = { name = "tailscale-apikey";             file = self + /secrets/tailscale/apikey.age;             extra = { owner = me; };                         };
    "tailscale.sshKey"     = { name = "tailscale-ssh-key";            file = self + /secrets/tailscale/ssh-key.age;            extra = { owner = me; };                         };
    "github.token"         = { name = "github-token";                 file = self + /secrets/github/token.age;                 extra = { owner = me; group = "users"; }; };
    "githubRepos.nixosConfig" = { name = "github-token-nixos-config"; file = self + /secrets/github/repos/token-nixos-config.age;   extra = { owner = me; };            };
    "githubRepos.obsidian"    = { name = "github-token-obsidian";     file = self + /secrets/github/repos/token-obsidian.age;        extra = { owner = me; };            };
    "system.cache"         = { name = "nixos-config-cache-token";     file = self + /secrets/cachix/nixos-config-cache-token.age;    extra = { owner = "root"; };        };
    "aws_cloud.apiKey"    = { name = "aws-cloud";              file = self + /secrets/cloud/aws/auth.age;              extra = { owner = me; }; };
    "aws_cloud.sshKey"    = { name = "aws-cloud-ssh-key";      file = self + /secrets/cloud/aws/ssh-key.age;      extra = { owner = me; }; };
    "aws_cloud.sshPubKey" = { name = "aws-cloud-ssh-pub-key";  file = self + /secrets/cloud/aws/ssh-pub-key.age;  extra = { owner = me; }; };
    "aws_labs.sshKey"    = { name = "aws-lab-ssh-key";      file = self + /secrets/cloud/aws/lab-ssh-key.age;      extra = { owner = me; }; };
  };

  # ── Helpers ─────────────────────────────────────────────────────────────────

  # Turn a dot-path string into a nested attrset.
  # "a.b.c" v  →  { a = { b = { c = v; }; }; }
  setAtPath = path: value:
    let parts = lib.splitString "." path;
    in lib.setAttrByPath parts value;

  # Build one age.secrets entry, guarded by mkIf (file != null).
  mkSecretEntry = _optPath: { name, file, extra }:
    mkIf (file != null) {
      age.secrets.${name} = {
        file  = lib.mkDefault file;
        owner = lib.mkDefault "root";
        mode  = lib.mkDefault "0400";
      } // extra;
    };

  # Build one nullOr path option, guarded by its default file.
  mkSecretOption = _optPath: { file, ... }:
    mkOption {
      type    = types.nullOr types.path;
      default = file;
    };

in
{
  imports = [ flake.inputs.agenix.nixosModules.default ];

  options.my.secrets = {
    enable = mkEnableOption "agenix-managed secrets";

    names = mkOption {
      readOnly    = true;
      description = "Attrset of agenix secret name strings, mirroring the secrets option layout.";
      default     = lib.foldl' lib.recursiveUpdate {}
        (mapAttrsToList
          (optPath: { name, ... }: setAtPath optPath name)
          secretDefs);
    };
  } // lib.foldl' lib.recursiveUpdate {}
      (mapAttrsToList
        (optPath: def: setAtPath optPath (mkSecretOption optPath def))
        secretDefs);

  config = mkIf cfg.enable (mkMerge
    (mapAttrsToList mkSecretEntry secretDefs)
  );
}