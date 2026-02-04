{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.bash;
in
{
  options.my.programs.bash = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Bash shell with custom configuration";
    };

    enableCompletion = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable bash completion";
    };

    enableVteIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable VTE integration for terminal working directory tracking";
    };

    historyControl = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "ignoredups" "ignorespace" ];
      description = "Control what is saved in history (ignoredups = no duplicates, ignorespace = ignore commands starting with space)";
    };

    historySize = lib.mkOption {
      type = lib.types.int;
      default = 10000;
      description = "Number of commands to keep in memory";
    };

    historyFileSize = lib.mkOption {
      type = lib.types.int;
      default = 100000;
      description = "Number of commands to persist to disk";
    };

    shellOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "histappend"    # Append to history file instead of overwriting
        "checkwinsize"  # Check window size after each command
        "cdspell"       # Correct minor spelling errors in cd commands
      ];
      description = "Shell options to enable (shopt)";
    };

    additionalShellOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional shell options to enable";
      example = [ "autocd" "globstar" ];
    };
  };

  config = lib.mkIf cfg.enable {
    programs.bash = {
      enable = true;
      enableCompletion = cfg.enableCompletion;
      enableVteIntegration = cfg.enableVteIntegration;
      historyControl = cfg.historyControl;
      historySize = cfg.historySize;
      historyFileSize = cfg.historyFileSize;
      shellOptions = cfg.shellOptions ++ cfg.additionalShellOptions;
    };
  };
}