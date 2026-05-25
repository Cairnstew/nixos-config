{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.windowsInstaller = {
    enable = mkEnableOption "automated Windows installer on first boot";

    windowsBuild = mkOption {
      type = types.str;
      default = "windows-11";
      description = ''
        Windows build to download and install.
        Examples: "windows-11", "windows-10"
      '';
    };

    windowsEdition = mkOption {
      type = types.str;
      default = "pro";
      description = ''
        Windows edition to install.
        Examples: "pro", "home", "enterprise"
      '';
    };

    windowsLang = mkOption {
      type = types.str;
      default = "en-gb";
      description = ''
        Language/locale for Windows installation.
        Examples: "en-gb", "en-us", "de-de"
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
