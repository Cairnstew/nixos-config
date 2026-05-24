{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.dscnix = {
    enable = mkEnableOption "DSC v3 YAML configuration generation via dscnix";

    configurationName = mkOption {
      type = types.str;
      default = "DSCConfiguration";
      description = "Name of the DSC configuration document.";
    };

    configFile = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = "Generated DSC YAML configuration file derivation.";
    };

    autoDerive = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically derive Windows configuration values from NixOS host config.";
      };

      hostname = mkOption {
        type = types.bool;
        default = true;
        description = "Derive Windows hostname from config.networking.hostName via registry.";
      };

      darkMode = mkOption {
        type = types.bool;
        default = true;
        description = "Derive Windows dark mode preference from flake config preferences.darkMode via registry.";
      };

      timezone = mkOption {
        type = types.bool;
        default = true;
        description = "Derive Windows timezone from config.time.timeZone (mapped via IANA→Windows TZ lookup).";
      };
    };

    registry = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          keyPath = mkOption {
            type = types.str;
            description = "Path to the registry key (e.g. HKLM\\Software\\...).";
          };
          valueName = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Name of the registry value. Required when specifying valueData.";
          };
          valueData = mkOption {
            type = types.nullOr (types.submodule {
              options = {
                String = mkOption { type = types.nullOr types.str; default = null; };
                ExpandString = mkOption { type = types.nullOr types.str; default = null; };
                MultiString = mkOption { type = types.nullOr (types.listOf types.str); default = null; };
                Binary = mkOption { type = types.nullOr (types.listOf (types.ints.between 0 255)); default = null; };
                DWord = mkOption { type = types.nullOr types.ints.unsigned; default = null; };
                QWord = mkOption { type = types.nullOr types.ints.unsigned; default = null; };
              };
            });
            default = null;
            description = "Registry value data. Specify exactly one of String, DWord, etc.";
          };
          exist = mkOption {
            type = types.bool;
            default = true;
            description = "Whether the registry key or value should exist.";
          };
          dependsOn = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Dependencies on other DSC resources.";
          };
        };
      }));
      default = {};
      description = "Windows Registry keys and values (Microsoft.Windows/Registry).";
    };

    windowsServices = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          displayName = mkOption { type = types.nullOr types.str; default = null; };
          description = mkOption { type = types.nullOr types.str; default = null; };
          status = mkOption {
            type = types.nullOr (types.enum [ "Running" "Stopped" "Paused" ]);
            default = null;
          };
          startType = mkOption {
            type = types.nullOr (types.enum [ "Automatic" "AutomaticDelayedStart" "Manual" "Disabled" ]);
            default = null;
          };
          executablePath = mkOption { type = types.nullOr types.str; default = null; };
          logonAccount = mkOption { type = types.nullOr types.str; default = null; };
          errorControl = mkOption {
            type = types.nullOr (types.enum [ "Ignore" "Normal" "Severe" "Critical" ]);
            default = null;
          };
          dependencies = mkOption { type = types.listOf types.str; default = []; };
          dependsOn = mkOption { type = types.listOf types.str; default = []; };
        };
      }));
      default = {};
      description = "Windows native services (Microsoft.Windows/Service).";
    };

    windowsFeatures = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          ensure = mkOption {
            type = types.enum [ "Present" "Absent" ];
            default = "Present";
          };
          include = mkOption { type = types.listOf types.str; default = []; };
          exclude = mkOption { type = types.listOf types.str; default = []; };
          dependsOn = mkOption { type = types.listOf types.str; default = []; };
        };
      }));
      default = {};
      description = "Windows features via Windows PowerShell 5.1 adapter (PSDscResources/WindowsFeature).";
    };

    firewallRules = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          description = mkOption { type = types.nullOr types.str; default = null; };
          applicationName = mkOption { type = types.nullOr types.str; default = null; };
          serviceName = mkOption { type = types.nullOr types.str; default = null; };
          protocol = mkOption {
            type = types.nullOr (types.ints.between 0 256);
            default = null;
          };
          localPorts = mkOption { type = types.nullOr types.str; default = null; };
          remotePorts = mkOption { type = types.nullOr types.str; default = null; };
          localAddresses = mkOption { type = types.nullOr types.str; default = null; };
          remoteAddresses = mkOption { type = types.nullOr types.str; default = null; };
          direction = mkOption {
            type = types.nullOr (types.enum [ "Inbound" "Outbound" ]);
            default = null;
          };
          action = mkOption {
            type = types.nullOr (types.enum [ "Allow" "Block" ]);
            default = null;
          };
          enabled = mkOption { type = types.nullOr types.bool; default = null; };
          profiles = mkOption {
            type = types.listOf (types.enum [ "Domain" "Private" "Public" "All" ]);
            default = [];
          };
          grouping = mkOption { type = types.nullOr types.str; default = null; };
          interfaceTypes = mkOption {
            type = types.listOf (types.enum [ "RemoteAccess" "Wireless" "Lan" "All" ]);
            default = [];
          };
          edgeTraversal = mkOption { type = types.nullOr types.bool; default = null; };
          exist = mkOption { type = types.bool; default = true; };
        };
      }));
      default = {};
      description = "Windows Firewall rules (Microsoft.Windows/FirewallRuleList). Note: Read-only in DSC v3.1.0.";
    };

    optionalFeatures = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          state = mkOption {
            type = types.enum [ "Installed" "NotPresent" "Removed" ];
            description = "Desired state of the optional feature.";
          };
          displayName = mkOption { type = types.nullOr types.str; default = null; };
          description = mkOption { type = types.nullOr types.str; default = null; };
        };
      }));
      default = {};
      description = "Windows Optional Features (Microsoft.Windows/OptionalFeatureList). Read-only in DSC v3.1.0.";
    };

    featuresOnDemand = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          state = mkOption {
            type = types.enum [ "Installed" "NotPresent" "Removed" ];
            description = "Desired state of the feature on demand.";
          };
          displayName = mkOption { type = types.nullOr types.str; default = null; };
          description = mkOption { type = types.nullOr types.str; default = null; };
        };
      }));
      default = {};
      description = "Windows Features on Demand (Microsoft.Windows/FeatureOnDemandList). Read-only in DSC v3.1.0.";
    };

    runCommands = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          executable = mkOption { type = types.str; description = "Executable to run on set."; };
          arguments = mkOption { type = types.listOf types.str; default = []; };
          exitCode = mkOption { type = types.ints.unsigned; default = 0; };
          dependsOn = mkOption { type = types.listOf types.str; default = []; };
        };
      }));
      default = {};
      description = "Commands to execute during DSC set (Microsoft.DSC.Transitional/RunCommandOnSet).";
    };

    powerShellScripts = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          getScript = mkOption { type = types.nullOr types.str; default = null; };
          setScript = mkOption { type = types.nullOr types.str; default = null; };
          testScript = mkOption { type = types.nullOr types.str; default = null; };
          input = mkOption { type = types.nullOr types.anything; default = null; };
          dependsOn = mkOption { type = types.listOf types.str; default = []; };
        };
      }));
      default = {};
      description = "Inline PowerShell 7 scripts (Microsoft.DSC.Transitional/PowerShellScript).";
    };

    windowsPowerShellScripts = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          getScript = mkOption { type = types.nullOr types.str; default = null; };
          setScript = mkOption { type = types.nullOr types.str; default = null; };
          testScript = mkOption { type = types.nullOr types.str; default = null; };
          input = mkOption { type = types.nullOr types.anything; default = null; };
          dependsOn = mkOption { type = types.listOf types.str; default = []; };
        };
      }));
      default = {};
      description = "Inline Windows PowerShell 5.1 scripts (Microsoft.DSC.Transitional/WindowsPowerShellScript).";
    };

    files = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          ensure = mkOption {
            type = types.enum [ "Present" "Absent" ];
            default = "Present";
          };
          sourcePath = mkOption { type = types.nullOr types.str; default = null; };
          destinationPath = mkOption { type = types.str; };
          dependsOn = mkOption { type = types.listOf types.str; default = []; };
        };
      }));
      default = {};
      description = "File resources via Windows PowerShell 5.1 adapter (PSDesiredStateConfiguration/File).";
    };

    services = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          ensure = mkOption {
            type = types.enum [ "Present" "Absent" ];
            default = "Present";
          };
          state = mkOption {
            type = types.enum [ "Running" "Stopped" ];
            default = "Running";
          };
          dependsOn = mkOption { type = types.listOf types.str; default = []; };
        };
      }));
      default = {};
      description = "Legacy Windows services (PSDesiredStateConfiguration/Service).";
    };

    osInfo = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          family = mkOption {
            type = types.nullOr (types.enum [ "Linux" "macOS" "Windows" ]);
            default = null;
          };
          edition = mkOption { type = types.nullOr types.str; default = null; };
          version = mkOption { type = types.nullOr types.str; default = null; };
          architecture = mkOption { type = types.nullOr types.str; default = null; };
          bitness = mkOption { type = types.nullOr types.int; default = null; };
        };
      }));
      default = {};
      description = "OS assertion resource (Microsoft/OSInfo). Read-only.";
    };

    rebootPending = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {};
      }));
      default = {};
      description = "Pending reboot assertion (Microsoft.Windows/RebootPending). Read-only.";
    };
  };
}
