{ flake, config, ... }:

let
  inherit (flake.inputs) self;
in
{
  zenBrowserPkg = zen-browser.packages.x86_64-linux.zen-browser;
}
