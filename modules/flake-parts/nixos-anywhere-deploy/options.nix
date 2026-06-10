{ lib, ... }:
let
  inherit (lib) types mkOption;
in
{
  options.my.nixosAnywhereDeploy = {
    hosts = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to generate deploy packages for this host.";
          };

          diskoMode = mkOption {
              type = types.nullOr (types.enum [
                "disko"
                "mount"
                "format"
                "none"
              ]);
              default = null;
              description = ''
                Disko partitioning mode. Auto-detected when null:
                - disk-config.nix sidecar exists → defaults to "disko"
                - no disk-config.nix → defaults to null (no disko flags)

                Values:
                - null    auto-detected (see above)
                - "disko" full create+format+mount. Safe for both first deploy
                          and redeploys because disko's blkid guards skip
                          mkfs on existing filesystems.
                - "format" format+mount only, no partitioning (use when the
                          partition table already exists and you want to force
                          a reformat of the NixOS filesystem).
                - "mount"  mount only, no partitioning or formatting (use for
                          quick redeploys where filesystems already exist).
                - "none"   no --disko-mode flag passed to nixos-anywhere.

                Override at runtime: nix run .#deploy-<host> -- <target> --disko-mode mount
              '';
          };

          extraArgs = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Extra arguments passed to nixos-anywhere.";
          };

          agentIdentity = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              SSH identity file path for connecting to the target (-i flag).
              When null, the wrapper falls back to $HOME/.ssh/id_ed25519.
              Tilde (~) and $HOME are expanded at runtime.
            '';
          };

          generateHostKey = mkOption {
            type = types.bool;
            default = false;
            description = "Enable agenix host key pre-provisioning. Generates a warning in the deploy wrapper if .deploy-keys/<host>/extra-files is missing, reminding the user to run prepare-keys.";
          };
        };
      });
      default = { };
      description = "Per-host nixos-anywhere deploy configuration.";
    };
  };
}
