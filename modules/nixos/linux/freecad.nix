{ pkgs, flake, ... }:

{
  environment.systemPackages = with pkgs; [
    freecad
  ];
}
