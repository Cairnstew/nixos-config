{ config, pkgs, ... }:

let
  myRPackages = with pkgs.rPackages; [
    ggplot2
    dplyr
    tidyr
    # Add any others you want here
  ];

  rstudio-with-my-packages = pkgs.rstudioWrapper.override { packages = myRPackages; };
in
{
  environment.systemPackages = with pkgs; [
    rstudio-with-my-packages
  ];
}
