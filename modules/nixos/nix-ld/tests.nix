{ config, lib, pkgs, ... }:

let
  cfg = config.my.system.nix-ld;

  # What actually lands in /run/current-system/sw/share/nix-ld/lib, i.e. what
  # the nix-ld loader hands to every unpatched binary.
  effectiveLibraries = config.programs.nix-ld.libraries;
  effectiveLibPaths = map (p: p.outPath) effectiveLibraries;

  # nixpkgs' own default set (nixos/modules/programs/nix-ld.nix). Duplicated
  # here on purpose: this test exists to catch the failure mode where
  # `my.system.nix-ld.libraries` replaces that set instead of extending it.
  nixpkgsDefaults = with pkgs; [
    zlib
    zstd
    stdenv.cc.cc
    curl
    openssl
    attr
    libssh
    bzip2
    libxml2
    acl
    libsodium
    util-linux
    xz
    systemd
  ];

  # Compare by outPath rather than derivation: `==` on derivations is structural
  # and two pkgs instances for the same package would compare unequal.
  missingDefaults = builtins.filter
    (p: !(builtins.elem p.outPath effectiveLibPaths))
    nixpkgsDefaults;
in
{
  # ── L0: Nix assertions ────────────────────────────────────────────────────
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.programs.nix-ld.enable;
        message = "my.system.nix-ld.enable must turn on NixOS' programs.nix-ld module, "
          + "otherwise nothing installs the loader and the option is a no-op.";
      }
      {
        # nix-ld assigns `environment.ldso` at normal priority while the
        # stub-ld shim assigns it with mkDefault — so nix-ld wins. If that ever
        # changes (upstream or by config), every generic binary goes back to
        # "Could not start dynamically linked executable … stub-ld".
        assertion =
          toString config.environment.ldso
          == "${config.programs.nix-ld.package}/libexec/nix-ld";
        message = "my.system.nix-ld is on but environment.ldso is "
          + "${toString config.environment.ldso}, not nix-ld's loader. The stub-ld "
          + "shim is winning the `environment.ldso` merge, so unpatched binaries will "
          + "still print the stub-ld error instead of running.";
      }
      {
        assertion = missingDefaults == [ ];
        message = "my.system.nix-ld.libraries must be *added to* nixpkgs' default library "
          + "set, not replace it. Missing from programs.nix-ld.libraries: "
          + "${builtins.concatStringsSep ", " (map (p: p.pname or p.name) missingDefaults)}. "
          + "List options merge by concatenation, so a host-set list should join the "
          + "defaults — an mkForce-style override would drop them. Keep "
          + "`programs.nix-ld.libraries = lib.mkAfter my.system.nix-ld.libraries` in "
          + "modules/nixos/nix-ld/config.nix.";
      }
    ];
  };
}
