{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.rstudio;

  myRPackages = with pkgs.rPackages; [
    ggplot2
    dplyr
    tidyr
    tidyverse
    # add more here
  ];

  rstudio-with-my-packages =
    pkgs.rstudioWrapper.override {
      packages = myRPackages;
    };
in
{
  options.my.programs.rstudio = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable RStudio with custom packages";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      rstudio-with-my-packages
    ];
  };
}
