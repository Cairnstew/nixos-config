{
  name = "homeManager";
  description = "Home Manager NixOS integration — wires all home-manager modules into a NixOS system user";
  category = "core";
  tags = [ "home-manager" "nixos" "integration" ];
  provides = [ "my.homeManager" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
  homepage = "https://nix-community.github.io/home-manager";
}
