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
                - disk-config.nix sidecar exists
                  - dualBoot mode is "useExisting" → defaults to "format"
                  - otherwise → defaults to "disko"
                - no disk-config.nix → defaults to null (no disko flags)

                Use "mount" for reinstalls where partitions already exist and
                should be preserved.
                Use "format" to wipe and reformat existing partitions without
                repartitioning.

              Runtime auto-detection (SSH pre-flight to check partition existence)
              is a potential future enhancement but out of scope here.
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
