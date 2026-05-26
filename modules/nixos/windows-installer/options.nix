{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types literalExpression;
  repoFromInput = "Cairnstew/uup-dump-build-and-get-windows-iso";
in
{
  options.my.services.windowsInstaller = {
    enable = mkEnableOption "automated Windows installer on first boot";

    windowsReleaseTag = mkOption {
      type = types.str;
      description = ''
        GitHub release tag for the pre-built Windows ISO.
        e.g. "26200.8521.25H2.MULTI.X64.PL.E.D.N"
        The tag encodes build, revision, channel, edition, architecture, and language.
      '';
    };

    windowsRepo = mkOption {
      type = types.str;
      default = repoFromInput;
      defaultText = literalExpression ''derived from flake.inputs.windows-iso-repo'';
      description = ''
        GitHub repository in "owner/repo" format where the Windows ISO release lives.
        Defaults to the repo URL from the windows-iso-repo flake input.
      '';
    };

    windowsImageIndex = mkOption {
      type = types.int;
      default = 2;
      description = ''
        Image index to install from the ISO. For MULTI-edition ISOs:
        1 = Home/Home Single Language, 2 = Professional.
      '';
    };

    isoChecksum = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Optional SHA-256 checksum of the ISO for verification after download.
        If set, the downloaded ISO will be checked against this hash.
        Example: "sha256:b5740d0452d97deea5a709c07c2e4af24bc8d2b98dfae4d4568d8e450101e40a"
      '';
    };

    windowsDisk = mkOption {
      type = types.str;
      default = "/dev/nvme0n1";
      description = ''
        The disk device where Windows will be installed.
        Should match my.disko.dualBoot.disk.
      '';
    };

    windowsPartitionIndex = mkOption {
      type = types.int;
      default = 2;
      description = ''
        1-based partition index that Windows Setup should install to.
        With dual-boot layout: 1=ESP, 2=Windows, 3=NixOS
        So default is 2 for the Windows partition.
      '';
    };

    localUsername = mkOption {
      type = types.str;
      default = "user";
      description = ''
        Username for the Windows local administrator account.
      '';
    };

    localPassword = mkOption {
      type = types.str;
      default = "";
      description = ''
        Password for the Windows local administrator account (plaintext).
        WARNING: Do not commit plaintext passwords to the repository.
        Prefer setting localPasswordFile to a runtime secret path instead.
        If both localPassword and localPasswordFile are set, localPasswordFile takes precedence.
      '';
    };

    localPasswordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to a file containing the Windows local admin password (e.g., an agenix decrypted secret).
        Read at runtime by the installer service, so it works with agenix paths like
        config.age.secrets.windows-password.path.
        Takes precedence over localPassword when set.
      '';
    };

    computerName = mkOption {
      type = types.str;
      default = "WINDOWS-PC";
      description = ''
        Computer name for the Windows system. Should match the NixOS hostname
        for consistency with dscnix auto-derivation.
      '';
    };

    timeZone = mkOption {
      type = types.str;
      default = "GMT Standard Time";
      description = ''
        Windows timezone identifier.
        Examples: "GMT Standard Time", "Pacific Standard Time", "Central European Standard Time"
      '';
    };

    isoOutputDir = mkOption {
      type = types.str;
      default = "/var/lib/windows-installer";
      description = ''
        Directory where Windows ISO and temporary files will be stored.
        Must have sufficient space (at least 10GB recommended).
      '';
    };

    autoReboot = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Automatically reboot the system after the ISO is prepared.
        When false (default), the user must manually reboot to start Windows Setup.
        BootNext is always set regardless of this option.
      '';
    };

    dscConfigPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Path to the dsc-configuration.yaml file produced by my.services.dscnix.
        This is a Nix store path (build-time), e.g. config.my.services.dscnix.configFile.
        Injected into the Windows ISO at sources\$OEM$\$$\Setup\Scripts\ for first-boot DSC apply.
      '';
    };
  };
}
