{ config, lib, inputs, withSystem, ... }:
let
  # flake-parts my.* namespace (renamed from config.ventoy)
  vCfg = config.my.ventoy;

  # Collect ventoy-tagged live ISOs from all NixOS host configs.
  hostVentoyIsos = builtins.foldl'
    (acc: hostName:
      let
        hostCfg = config.flake.nixosConfigurations.${hostName} or { };
        hostLive = hostCfg.config.my.live or { };
      in
      if hostLive ? isos then
        acc // lib.filterAttrs (_: iso: iso.ventoy or false) hostLive.isos
      else
        acc
    )
    { }
    (builtins.attrNames (config.flake.nixosConfigurations or { }));

  storeHash = p:
    let name = builtins.baseNameOf p;
    in lib.head (lib.splitString "-" name);

  # ── JSON helpers (mirrors old ventoy.nix) ─────────────────────────

  mkThemeJson = theme: lib.filterAttrs (_: v: v != null && v != [ ])
    {
      inherit (theme) file gfxmode display_mode fonts;
    } // lib.optionalAttrs (theme.default_file != null) {
    default_file = theme.default_file;
  } // lib.optionalAttrs (theme.resolution_fit != null) {
    resolution_fit = theme.resolution_fit;
  } // lib.optionalAttrs (theme.serial_param != null) {
    serial_param = theme.serial_param;
  } // lib.optionalAttrs (theme.ventoy_left != null) {
    ventoy_left = theme.ventoy_left;
  } // lib.optionalAttrs (theme.ventoy_top != null) {
    ventoy_top = theme.ventoy_top;
  } // lib.optionalAttrs (theme.ventoy_color != null) {
    ventoy_color = theme.ventoy_color;
  };

  cleanJSON = val:
    if builtins.isAttrs val then
      lib.filterAttrs (_: v: v != null)
        (lib.mapAttrs (_: v: cleanJSON v) val)
    else if builtins.isList val then
      builtins.filter (v: v != null)
        (map (v: cleanJSON v) val)
    else
      val;

  shouldInclude = val:
    val != null
    && !(builtins.isList val && val == [ ])
    && !(val == { });

  cleanPluginValue = baseName: raw:
    if raw == null then null
    else if baseName == "theme" then mkThemeJson raw
    else if builtins.isList raw then map cleanJSON raw
    else if builtins.isAttrs raw then cleanJSON raw
    else raw;

  pluginNames = vCfg._internal.pluginNames;
  modeSuffixes = vCfg._internal.modeSuffixes;

in
{
  # ventoy-deploy / ventoy-bundle are exported as top-level flake outputs
  # rather than as packages. `nix flake check` requires every
  # packages.<system>.<name> to be a derivation, so it forces their entire
  # closure — including the Windows ISO from the windows-iso-src input — and
  # OOMs the evaluator on the server. An unknown flake output only produces a
  # "warning: unknown flake output" line and is never forced, so a full check
  # skips them while `nix run .#ventoy-deploy` keeps working unchanged.
  flake = lib.optionalAttrs (builtins.elem "x86_64-linux" config.systems) (
    withSystem "x86_64-linux" ({ pkgs, config, ... }:
      let
        # ── ventoy.json ───────────────────────────────────────────────
        ventoyJson =
          let
            entries = lib.flatten (lib.forEach pluginNames (baseName:
              lib.forEach modeSuffixes (suffix:
                let
                  key = if suffix == "" then baseName else "${baseName}_${suffix}";
                  raw = vCfg.settings.${key} or null;
                  cleaned = cleanPluginValue baseName raw;
                in
                lib.optional (shouldInclude cleaned) {
                  name = key;
                  value = cleaned;
                })
            ));
          in
          builtins.listToAttrs entries // vCfg.extraConfig;

        ventoyJsonFile = pkgs.writeText "ventoy.json" (builtins.toJSON ventoyJson);

        # ── Auto-detect ventoy-tagged live ISOs ──────────────────────────
        # Collected from NixOS host configs at the top level above.
        ventoyLiveIsos = lib.mapAttrs'
          (name: iso:
            lib.nameValuePair "live-${name}" {
              source = config.packages.${"live-iso-${name}"} or (throw "live-iso-${name} not found — is the live-iso module enabled?");
              target = "/iso/linux/${name}.iso";
            }
          )
          hostVentoyIsos;

        # ── ISO mappings ──────────────────────────────────────────────
        gpartedIso = pkgs.runCommand "gparted-live-1.6.0-1-amd64.iso" { } ''
          cp ${inputs.gparted-iso} $out
        '';

        allIsos = vCfg.isos // ventoyLiveIsos // {
          gparted = {
            source = gpartedIso;
            target = "/iso/linux/gparted-live-1.6.0-1-amd64.iso";
          };
        };

        isoMappings = lib.mapAttrsToList
          (name: iso:
            ''"${iso.source}|${iso.target}|${storeHash iso.source}"''
          )
          allIsos;

        # ── File mappings ─────────────────────────────────────────────
        # Answer-file packages are exported by answer-files.nix into the
        # same perSystem evaluation. Reference via forward-reference:
        # they are in config.packages because that module's perSystem has
        # already merged.
        fileMappings =
          let
            answerPkgNames = builtins.attrNames config.packages;
            answerXmlPkgs = builtins.filter
              (n: lib.hasPrefix "windows-answ-pro-" n)
              answerPkgNames;
          in
          map
            (name:
              let
                pkg = config.packages.${name};
                profileName = lib.removePrefix "windows-answ-pro-" name;
                target = "/ventoy/scripts/${profileName}.xml";
              in
              ''"${pkg}|${target}|${storeHash pkg}"'')
            answerXmlPkgs;

        # ── ventoy-bundle ─────────────────────────────────────────────
        ventoy-bundle = pkgs.runCommand "ventoy-bundle" { } ''
          mkdir -p $out/ventoy
          cp "${ventoyJsonFile}" $out/ventoy/ventoy.json
          ${lib.optionalString (vCfg.grubConfig != null) ''
            cp "${vCfg.grubConfig}" $out/ventoy/ventoy_grub.cfg
          ''}
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: iso: ''
            TARGET="$out/${iso.target}"
            mkdir -p "$(dirname "$TARGET")"
            ln -s "${iso.source}" "$TARGET"
          '') vCfg.isos)}
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: pkg: let
            profileName = lib.removePrefix "windows-answ-pro-" name;
            target = "/ventoy/scripts/${profileName}.xml";
          in ''
            mkdir -p "$out/ventoy/scripts"
            cp "${pkg}" "$out${target}"
          '') (lib.filterAttrs (n: _: lib.hasPrefix "windows-answ-pro-" n) config.packages))}
        '';

        ventoyIso = config.packages.live-iso-deploy or null;
      in
      {
        ventoy-deploy = pkgs.callPackage ./deploy-script {
          inherit (vCfg) device mountPoint;
          buildInstallerIso = ventoyIso != null;
          ventoyJson = ventoyJsonFile;
          grubConfig = vCfg.grubConfig;
          isoMappings = isoMappings;
          fileMappings = fileMappings;
          installerIso = ventoyIso;
          secureBoot = vCfg.installOptions.secureBoot;
          gpt = vCfg.installOptions.gpt;
          label = vCfg.installOptions.label;
          reserveSizeMb = vCfg.installOptions.reserveSizeMb;
        };
        ventoy-bundle = ventoy-bundle;
      })
  );

  # The deploy-script smoke test needs no ISO, so it stays a real check.
  perSystem = { pkgs, ... }: {
    checks.ventoy-deploy-tests = pkgs.callPackage ./deploy-script/tests.nix { };
  };
}
