{ pkgs, ... }:
{
  imports = [
    ./all/terminal/zsh.nix
    ./all/terminal/bash.nix
  ];
}
