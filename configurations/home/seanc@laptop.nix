{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  homeMod = self + /modules/home;
in
{
  imports = [
    self.homeModules.default
    #self.homeModules.youtube-music
    
  ];

  programs.youtube-music.enable = true;

  home.username = "seanc";
}
