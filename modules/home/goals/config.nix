{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf;
  cfg = config.my.programs.goals;
in
{
  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.python3.withPackages (ps: [ ]))
    ];

    home.file."${cfg.dataDir}/.keep".text = "";

    my.programs.opencode.commands.daily-focus = ./commands/daily-focus.md;

    my.programs.opencode.mcp.goals = {
      enabled = true;
      type = "local";
      command = [
        "${pkgs.python3.withPackages (ps: [ ])}/bin/python3"
        "${./mcp_server.py}"
        "--db"
        "${cfg.dataDir}/goals.db"
        "--schema"
        "${./schema.sql}"
        "--decay-factor"
        (toString cfg.decayFactor)
        "--min-days"
        (toString cfg.minPromotionDays)
        "--min-count"
        (toString cfg.minPromotionCount)
        "--promotion-confidence"
        (toString cfg.promotionConfidenceThreshold)
        "--retire-confidence"
        (toString cfg.retireConfidenceThreshold)
        "--at-risk-threshold"
        (toString cfg.timelineAtRiskThreshold)
        "--behind-threshold"
        (toString cfg.timelineBehindThreshold)
      ];
      timeout = 120000;
    };
  };
}
