{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  homeMod = self + /modules/home;
in
{
  imports = [
    self.homeModules.default
    "${homeMod}/all/spotify.nix"
    "${homeMod}/all/vscode.nix"
    
  ];

  home.username = "seanc";
}
