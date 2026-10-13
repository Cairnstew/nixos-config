{
  name = "nix-ld";
  description = "nix-ld: run unpatched dynamic ELF binaries on NixOS (Zed's downloaded language servers, self-updating apps, AppImages)";
  category = "system";
  tags = [
    "nix-ld"
    "compat"
    "elf"
    "loader"
    "stub-ld"
    "zed"
  ];
  provides = [ "my.system.nix-ld" ];
  complexity = "simple";
  tested = true;
  homepage = "https://github.com/nix-community/nix-ld";
  maintainer = "seanc";
}
