{ config, lib, inputs, ... }:
let
  cfg = config.my.nixosAnywhereDeploy;
  hostOptions = cfg.hosts or { };

  allHostNames = builtins.attrNames (config.flake.nixosConfigurations or { });

  enabledHosts = builtins.filter (name:
    if builtins.hasAttr name hostOptions then
      hostOptions.${name}.enable or true
    else
      true
  ) allHostNames;

  root = toString ./../../..;
  hostHasDiskConfig = hostName:
    builtins.pathExists "${root}/configurations/nixos/${hostName}/disk-config.nix";

  getNixOSConfig = hostName:
    config.flake.nixosConfigurations.${hostName} or null;

  getNixOSCfg = hostName:
    let c = getNixOSConfig hostName; in
    if c != null then c.config else { };

  isDualBootUseExisting = hostName:
    let cfg = getNixOSCfg hostName;
    in cfg ? my.disko.dualBoot
    && cfg.my.disko.dualBoot.enable or false
    && cfg.my.disko.dualBoot.mode or "" == "useExisting";

  getHostCfg = hostName:
    if builtins.hasAttr hostName hostOptions then hostOptions.${hostName} else { };

  generateHostKeyGuard = builtins.concatLists (map (hostName:
    let
      opts = getHostCfg hostName;
      hasDisk = hostHasDiskConfig hostName;
    in
    if opts ? generateHostKey && opts.generateHostKey && !hasDisk then
      let
        msg = "${hostName}: generateHostKey is enabled but no disk-config.nix sidecar exists. Host key generation is pointless — this host does not use disko provisioning. Set my.nixosAnywhereDeploy.hosts.${hostName}.generateHostKey = false.";
      in
      [ (builtins.warn msg null) ]
    else
      [ ]
  ) allHostNames) == [ ];

  mkDeployPkg = hostName: pkgs:
    let
      opts = getHostCfg hostName;
      autoMode = if hostHasDiskConfig hostName then "disko" else null;
      diskoMode = if opts ? diskoMode && opts.diskoMode != null then opts.diskoMode else autoMode;
      nixosAnywhereBin = "${inputs.nixos-anywhere.packages.${pkgs.system}.default}/bin/nixos-anywhere";
      identityStr = if opts ? agentIdentity && opts.agentIdentity != null then opts.agentIdentity else "";
      # Auto-detect generateHostKey: enabled when host uses dualBoot (which
      # needs SSH host keys for agenix), OR when explicitly set in options.
      autoHostKey = let nixosCfg = getNixOSCfg hostName; in
        nixosCfg ? my.disko.dualBoot
        && nixosCfg.my.disko.dualBoot.enable or false;
      genHostKeyFlag = if opts ? generateHostKey then
        if opts.generateHostKey then "1" else "0"
      else if autoHostKey then "1" else "0";
      extraArgsStr = lib.concatStringsSep " " (if opts ? extraArgs then opts.extraArgs else [ ]);
    in
    pkgs.writeShellApplication {
      name = "deploy-${hostName}";
      text = ''
        set -euo pipefail

        target="''${1:?Usage: nix run .#deploy-${hostName} -- <ssh-target>}"
        shift

        identity="${if identityStr != "" then identityStr else "\$HOME/.ssh/id_ed25519"}"
        extraFiles="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")/.deploy-keys/${hostName}/extra-files"

        extraArgs=(--flake ".#${hostName}" "$target" -i "$identity")

        ${if diskoMode != null then ''
        extraArgs+=(--disko-mode "${diskoMode}")
        '' else ""}

        ${if genHostKeyFlag == "1" then ''
        if [ -d "$extraFiles" ]; then
          extraArgs+=(--extra-files "$extraFiles")
        else
          echo "Warning: generateHostKey is enabled but $extraFiles not found." >&2
          echo "Run: nix run .#prepare-keys-${hostName}" >&2
        fi
        '' else ''
        if [ -d "$extraFiles" ]; then
          extraArgs+=(--extra-files "$extraFiles")
        fi
        ''} 

        ${if extraArgsStr != "" then "extraArgs+=(${extraArgsStr})" else ""}

        exec ${nixosAnywhereBin} "''${extraArgs[@]}" "$@"
      '';
    };

  mkDeployTest = hostName: pkgs:
    let
      nixosConfig = config.flake.nixosConfigurations.${hostName} or null;
    in
    if nixosConfig != null then
      nixosConfig.config.system.build.toplevel
    else
      null;
in
{
  perSystem = { pkgs, ... }:
    let
      isLinux = builtins.elem pkgs.system [ "x86_64-linux" "aarch64-linux" ];

      deployPkgs = if isLinux then
        builtins.listToAttrs (map (hostName:
          lib.nameValuePair "deploy-${hostName}" (mkDeployPkg hostName pkgs)
        ) enabledHosts)
      else { };

      testPkgs = if isLinux then
        lib.filterAttrs (_: v: v != null)
          (builtins.listToAttrs (map (hostName:
            lib.nameValuePair "build-${hostName}" (mkDeployTest hostName pkgs)
          ) enabledHosts))
      else { };
    in
    {
      packages = deployPkgs;
      checks = testPkgs;
    };
}
