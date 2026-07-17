{ config, lib, ... }:

let
  inherit (lib) mkEnableOption mkOption types literalExpression;
in
{
  options.my.programs.goals = {
    enable = mkEnableOption "personal goals tracker with MCP trait updates";

    dataDir = mkOption {
      type = types.path;
      default = "${config.xdg.dataHome}/goals";
      defaultText = literalExpression ''"''${config.xdg.dataHome}/goals"'';
      description = "Directory for the SQLite database and persistent state.";
    };

    decayFactor = mkOption {
      type = types.float;
      default = 0.98;
      description = "Weekly decay factor for trait confidence (0.0-1.0).";
    };

    minPromotionDays = mkOption {
      type = types.int;
      default = 3;
      description = "Minimum distinct days of evidence needed for trait promotion.";
    };

    minPromotionCount = mkOption {
      type = types.int;
      default = 5;
      description = "Minimum total observations needed for trait promotion.";
    };

    promotionConfidenceThreshold = mkOption {
      type = types.float;
      default = 0.65;
      description = "Confidence threshold (0.0-1.0) above which a trait can be promoted.";
    };

    retireConfidenceThreshold = mkOption {
      type = types.float;
      default = 0.35;
      description = "Confidence threshold below which an active trait is retired.";
    };
  };
}
