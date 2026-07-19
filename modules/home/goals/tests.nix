{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.goals;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.decayFactor > 0.0 && cfg.decayFactor <= 1.0;
        message = "my.programs.goals.decayFactor must be between 0.0 and 1.0";
      }
      {
        assertion = cfg.minPromotionDays >= 1;
        message = "my.programs.goals.minPromotionDays must be at least 1";
      }
      {
        assertion = cfg.minPromotionCount >= 1;
        message = "my.programs.goals.minPromotionCount must be at least 1";
      }
      {
        assertion = cfg.promotionConfidenceThreshold >= 0.0 && cfg.promotionConfidenceThreshold <= 1.0;
        message = "my.programs.goals.promotionConfidenceThreshold must be between 0.0 and 1.0";
      }
      {
        assertion = cfg.retireConfidenceThreshold >= 0.0 && cfg.retireConfidenceThreshold <= 1.0;
        message = "my.programs.goals.retireConfidenceThreshold must be between 0.0 and 1.0";
      }
      {
        assertion = cfg.timelineAtRiskThreshold >= 0.0 && cfg.timelineAtRiskThreshold <= 1.0;
        message = "my.programs.goals.timelineAtRiskThreshold must be between 0.0 and 1.0";
      }
      {
        assertion = cfg.timelineBehindThreshold > cfg.timelineAtRiskThreshold;
        message = "my.programs.goals.timelineBehindThreshold must be greater than timelineAtRiskThreshold";
      }
    ];
  };
}
