{ flake, lib, config, pkgs, ... }:

let
  inherit (flake) config inputs;
in
{
  nixpkgs.config = {
    permittedInsecurePackages = [
      "ventoy-1.1.05"
      "ventoy-qt5-1.1.05"
      "ventoy-gtk3-1.1.05"
    ];
  };

  environment.systemPackages = with pkgs; [
    ventoy
    ventoy-full
    ventoy-full-qt
    ventoy-full-gtk
  ];
}
