{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  homeMod = self + /modules/home;
in
{
  imports = [
    self.homeModules.default
    "${homeMod}/all/vscode.nix"
    
  ];

  home.username = "seanc";
}
