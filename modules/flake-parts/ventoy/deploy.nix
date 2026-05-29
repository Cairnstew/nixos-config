{ config, lib, inputs, ... }:
let
  vCfg = config.ventoy;

  storeHash = p:
    let name = builtins.baseNameOf p;
    in lib.head (lib.splitString "-" name);

  # ── JSON helpers (mirrors old ventoy.nix) ─────────────────────────

  mkThemeJson = theme: lib.filterAttrs (_: v: v != null && v != [ ]) {
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

in {
  config.perSystem = { pkgs, system, config, ... }:
    let
      # ── ventoy.json ───────────────────────────────────────────────
      ventoyJson = let
        entries = lib.flatten (lib.forEach pluginNames (baseName:
          lib.forEach modeSuffixes (suffix: let
            key = if suffix == "" then baseName else "${baseName}_${suffix}";
            raw = vCfg.settings.${key} or null;
            cleaned = cleanPluginValue baseName raw;
          in lib.optional (shouldInclude cleaned) {
            name = key;
            value = cleaned;
          })
        ));
      in builtins.listToAttrs entries // vCfg.extraConfig;

      ventoyJsonFile = pkgs.writeText "ventoy.json" (builtins.toJSON ventoyJson);

      # ── ISO mappings ──────────────────────────────────────────────
      gpartedIso = pkgs.runCommand "gparted-live-1.6.0-1-amd64.iso" { } ''
        cp ${inputs.gparted-iso} $out
      '';

      allIsos = vCfg.isos // {
        gparted = {
          source = gpartedIso;
          target = "/iso/linux/gparted-live-1.6.0-1-amd64.iso";
        };
      };

      isoMappings = lib.mapAttrsToList (name: iso:
        ''"${iso.source}|${iso.target}|${storeHash iso.source}"''
      ) allIsos;

      # ── File mappings ─────────────────────────────────────────────
      # Answer-file packages are exported by answer-files.nix into the
      # same perSystem evaluation. Reference via forward-reference:
      # they are in config.packages because that module's perSystem has
      # already merged.
      fileMappings = let
        answerPkgNames = builtins.attrNames config.packages;
        answerXmlPkgs = builtins.filter
          (n: lib.hasPrefix "windows-answ-pro-" n) answerPkgNames;
      in map (name: let
        pkg = config.packages.${name};
        profileName = lib.removePrefix "windows-answ-pro-" name;
        target = "/ventoy/scripts/${profileName}.xml";
      in ''"${pkg}|${target}|${storeHash pkg}"'') answerXmlPkgs;

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

    in {
      packages = {
        ventoy-deploy = pkgs.callPackage ./deploy-script {
          inherit (vCfg) device mountPoint buildInstallerIso;
          ventoyJson = ventoyJsonFile;
          grubConfig = vCfg.grubConfig;
          isoMappings = isoMappings;
          fileMappings = fileMappings;
          installerIso = if vCfg.buildInstallerIso
            then config.packages.installer-iso or null
            else null;
          secureBoot = vCfg.installOptions.secureBoot;
          gpt = vCfg.installOptions.gpt;
          label = vCfg.installOptions.label;
          reserveSizeMb = vCfg.installOptions.reserveSizeMb;
        };
        ventoy-bundle = ventoy-bundle;
      };
      checks = {
        ventoy-deploy-tests = pkgs.callPackage ./deploy-script/tests.nix { };
      };
    };
}
