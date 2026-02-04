{ flake, config, pkgs, ... }:

let
  inherit (flake.inputs) self;

  # Access Zen Browser package from the input
  zenBrowserPkg = zen-browser.packages.x86_64-linux.zen-browser;

in
{
  # Add Zen Browser to systemPackages
  environment.systemPackages = with pkgs; [
    zenBrowserPkg  # Add zen-browser package to the system
  ];
}
