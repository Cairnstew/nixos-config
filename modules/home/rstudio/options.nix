{ lib, pkgs, ... }:

let
  types = lib.types;
in
{
  options.my.programs.rstudio = {
    enable = lib.mkEnableOption "RStudio IDE with custom packages";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.rstudioWrapper;
      defaultText = lib.literalExpression "pkgs.rstudioWrapper";
      description = "The RStudio package to use.";
    };

    rPackages = lib.mkOption {
      type = types.listOf types.package;
      default = with pkgs.rPackages; [
        ggplot2
        dplyr
        tidyr
        tidyverse
        ggrepel
        pagedown
      ];
      defaultText = lib.literalExpression ''
        with pkgs.rPackages; [ ggplot2 dplyr tidyr tidyverse ggrepel pagedown ]
      '';
      description = "List of R packages to bundle with RStudio.";
    };

    extraPackages = lib.mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra packages to install alongside RStudio.";
    };
  };
}
