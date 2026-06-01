{ lib, ... }:
{
  options.my.programs.helix-ide = {
    enable = lib.mkEnableOption "Helix editor + Zellij IDE environment";

    inlineDiagnostics = lib.mkOption {
      type = lib.types.enum [ "none" "hint" "warning" ];
      default = "hint";
      description = "Display diagnostics inline. Options: none, hint, or warning";
    };

    inlayHints = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show inline type hints and parameter names from the LSP";
    };

    relativeLines = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use relative line numbering for faster modal vertical motions";
    };

    rainbowRulers = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add modern visual color column indicators for clean indentation";
    };
  };
}
