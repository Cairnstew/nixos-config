{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
  inherit (lib.types) attrs attrsOf bool enum int listOf nullOr path str submodule raw;

  # Shared submodule for machine + profile options
  machineModule = { ... }: {
    options = {
      macAddress = mkOption {
        type = str;
        default = "";
        description = "MAC address of the target machine (ignored in profiles)";
      };

      stages = mkOption {
        type = listOf (enum [ "discover" "windows" "nixos" "done" ]);
        default = [ "windows" "nixos" "done" ];
        description = "Ordered list of boot stages";
      };

      dscConfig = mkOption {
        type = attrs;
        default = { };
        description = ''
          DSC v3 configuration data passed to dscnix's evalDscConfiguration.
          Mirrors the shape of my.services.dscnix.* options.
          Keys: configurationName, registry, optionalFeatures, runCommands, etc.
          Hostname is auto-derived from windows.unattended.computerName.
          Set to {} to skip DSC bootstrap entirely.
        '';
      };

      windows = {
        unattended = {
          enable = mkEnableOption "unattended Windows install with autounattend.xml";

          edition = mkOption {
            type = str;
            default = "Windows 11 Pro";
            description = "Windows edition matched via /IMAGE/NAME in boot.wim";
          };

          localUser = mkOption {
            type = str;
            default = "nixos";
            description = "Local administrator username created during Windows setup";
          };

          password = mkOption {
            type = str;
            default = "nixos";
            description = ''
              Plaintext Windows admin password embedded in autounattend.xml.
              Windows Setup requires the password in plaintext in the answer file.
              The XML is served over HTTP during PXE boot — anyone on the network
              can see this password. Use 'passwordFile' to read from an agenix
              secret instead.
            '';
          };

          passwordFile = mkOption {
            type = nullOr path;
            default = null;
            description = ''
              Path to a file containing the plaintext Windows admin password.
              If set, overrides the 'password' option. The file is read at
              evaluation time with builtins.readFile. For agenix secrets, use
              config.age.secrets.windows-password.path — but note this won't
              exist at eval time if it's a runtime path.
            '';
          };

          timeZone = mkOption {
            type = str;
            default = "GMT Standard Time";
            description = "Windows timezone identifier";
          };

          computerName = mkOption {
            type = str;
            default = "";
            description = "Windows computer name";
          };

          disableRecovery = mkOption {
            type = bool;
            default = true;
            description = "Disable automatic recovery partition creation";
          };
        };
      };

      nixos = {
        autoInstall = {
          enable = mkEnableOption "automated NixOS install via custom netboot image";

          diskoConfig = mkOption {
            type = raw;
            default = { };
            description = "disko configuration attrset defining the target's disk layout";
          };

          nixosConfig = mkOption {
            type = str;
            default = "";
            description = ''
              NixOS module expression for the target system.
              Must be a valid Nix expression string, e.g.:
              { config, pkgs, lib, ... }: { networking.hostName = "desktop"; ... }
            '';
          };
        };
      };
    };
  };

  profileModule = { ... }: {
    options = {
      enable = mkEnableOption "this netboot profile";

      description = mkOption {
        type = str;
        default = "Netboot profile";
        description = "Human-readable description of this profile";
      };

      stages = mkOption {
        type = listOf (enum [ "discover" "windows" "nixos" "done" ]);
        default = [ "windows" "nixos" "done" ];
        description = "Ordered list of boot stages";
      };

      dscConfig = mkOption {
        type = attrs;
        default = { };
        description = ''
          DSC v3 configuration data passed to dscnix's evalDscConfiguration.
          Mirrors the shape of my.services.dscnix.* options.
          Keys: configurationName, registry, optionalFeatures, runCommands, etc.
          Hostname is auto-derived from windows.unattended.computerName.
          Set to {} to skip DSC bootstrap entirely.
        '';
      };

      windows = {
        unattended = {
          enable = mkEnableOption "unattended Windows install with autounattend.xml";

          edition = mkOption {
            type = str;
            default = "Windows 11 Pro";
            description = "Windows edition matched via /IMAGE/NAME in boot.wim";
          };

          localUser = mkOption {
            type = str;
            default = "nixos";
            description = "Local administrator username created during Windows setup";
          };

          password = mkOption {
            type = str;
            default = "nixos";
            description = ''
              Plaintext Windows admin password embedded in autounattend.xml.
              Windows Setup requires the password in plaintext in the answer file.
              The XML is served over HTTP during PXE boot — anyone on the network
              can see this password. Use 'passwordFile' to read from an agenix
              secret instead.
            '';
          };

          passwordFile = mkOption {
            type = nullOr path;
            default = null;
            description = ''
              Path to a file containing the plaintext Windows admin password.
              If set, overrides the 'password' option. The file is read at
              evaluation time with builtins.readFile. For agenix secrets, use
              config.age.secrets.windows-password.path — but note this won't
              exist at eval time if it's a runtime path.
            '';
          };

          timeZone = mkOption {
            type = str;
            default = "GMT Standard Time";
            description = "Windows timezone identifier";
          };

          computerName = mkOption {
            type = str;
            default = "";
            description = "Windows computer name";
          };

          disableRecovery = mkOption {
            type = bool;
            default = true;
            description = "Disable automatic recovery partition creation";
          };
        };
      };

      nixos = {
        autoInstall = {
          enable = mkEnableOption "automated NixOS install via custom netboot image";

          diskoConfig = mkOption {
            type = raw;
            default = { };
            description = "disko configuration attrset defining the target's disk layout";
          };

          nixosConfig = mkOption {
            type = str;
            default = "";
            description = ''
              NixOS module expression for the target system.
              Must be a valid Nix expression string, e.g.:
              { config, pkgs, lib, ... }: { networking.hostName = "desktop"; ... }
            '';
          };
        };
      };
    };
  };
in
{
  options.my.services.netboot = {
    enable = mkEnableOption "PXE netboot server (DHCP + TFTP + HTTP)";

    serveMode = mkOption {
      type = enum [ "cli" "daemon" ];
      default = "cli";
      description = ''
        "cli" — install the netboot-serve CLI tool. Run it interactively with
          sudo nix run .#netboot-serve (or just "netboot-serve" after install).
          Prints status, accepts "advance <mac>" commands, stops with Ctrl+C.

        "daemon" — run as persistent systemd services (dnsmasq, nginx, webhook).
          Starts on boot, runs in background. Use "netboot-advance" to manage.
      '';
    };

    interface = mkOption {
      type = str;
      default = "eth0";
      description = "Network interface to bind the PXE server to";
    };

    serverAddress = mkOption {
      type = str;
      default = "192.168.100.1";
      description = "Static IP address for the PXE server interface";
    };

    subnetPrefix = mkOption {
      type = int;
      default = 24;
      description = "Subnet prefix length for the PXE server interface";
    };

    dhcpRange = mkOption {
      type = str;
      default = "192.168.100.100,192.168.100.150";
      description = "DHCP lease range (start,end)";
      example = "192.168.100.100,192.168.100.150";
    };

    dhcpLeaseTime = mkOption {
      type = str;
      default = "12h";
      description = "DHCP lease duration";
      example = "12h";
    };

    tftpRoot = mkOption {
      type = path;
      default = "/srv/tftp";
      description = "Root directory for TFTP (iPXE binaries)";
    };

    httpRoot = mkOption {
      type = path;
      default = "/srv/pxe";
      description = "Root directory for HTTP (iPXE scripts, boot images)";
    };

    windows = {
      enable = mkEnableOption "Windows installer PXE boot stage";

      bootDir = mkOption {
        type = path;
        default = "/srv/pxe/windows";
        description = ''
          Directory containing extracted Windows boot files.
          Matches the default outputDir of my.services.windowsIsoSync.
          Expects: boot/bcd, boot/boot.sdi, sources/boot.wim
        '';
      };
    };

    nixos = {
      enable = mkEnableOption "NixOS installer PXE boot stage";

      ipxeUrl = mkOption {
        type = str;
        default = "https://github.com/nix-community/nixos-images/releases/download/nixos-unstable/netboot-x86_64-linux.ipxe";
        description = "URL to the NixOS netboot iPXE script (used when autoInstall is disabled)";
      };

      label = mkOption {
        type = str;
        default = "NixOS Unstable";
        description = "Display label for the NixOS installer";
      };
    };

    machines = mkOption {
      type = attrsOf (submodule machineModule);
      default = { };
      example = {
        my-desktop = {
          macAddress = "00:11:22:33:44:55";
          stages = [ "windows" "nixos" "done" ];
          windows.unattended = {
            enable = true;
            computerName = "TARGET-PC";
          };
          nixos.autoInstall = {
            enable = true;
            diskoConfig = { };
            nixosConfig = "";
          };
        };
      };
      description = "Per-MAC machine definitions for multi-stage netboot (used by daemon mode)";
    };

    profiles = mkOption {
      type = attrsOf (submodule profileModule);
      default = { };
      example = {
        dual-boot = {
          enable = true;
          description = "NixOS + Windows 11 dual boot";
          stages = [ "discover" "windows" "nixos" "done" ];
        };
        nixos-minimal = {
          enable = true;
          description = "NixOS only (erase entire disk)";
          stages = [ "nixos" "done" ];
        };
      };
      description = "Reusable boot profile templates (used by netboot-serve wizard)";
    };
  };
}
