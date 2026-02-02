{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
 
  imports = [
    ./git.nix
    ./direnv.nix
    ./ghostty.nix
    #./just.nix
    #./gotty.nix
  ];
  
}
