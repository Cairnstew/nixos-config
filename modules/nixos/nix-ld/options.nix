{ lib, ... }:
{
  options.my.system.nix-ld = {

    enable = lib.mkEnableOption "nix-ld (run unpatched dynamic ELF binaries on NixOS)";

    libraries = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.libGL pkgs.fontconfig ]";
      description = ''
        Extra libraries to append to nix-ld's default set (nixpkgs' list in
        `programs.nix-ld.libraries`: zlib, zstd, gcc, curl, openssl, attr,
        libssh, bzip2, libxml2, acl, libsodium, util-linux, xz, systemd).

        Defaults are kept — this list is *added* to them, never a replacement.
        Only add entries when a specific binary you run actually needs them:
        check what it asks for with `readelf -d <binary> | grep NEEDED`
        (or `ldd <binary>`) and compare against the paths under
        `/run/current-system/sw/share/nix-ld/lib` after the switch.
      '';
    };
  };
}
