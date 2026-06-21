{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.sillytavern;
  vfcfg = cfg.extensions.vectfox;
  pcfg = cfg.presets;
  homeDir = "/var/lib/sillytavern";
  stUserDir = "${homeDir}/.local/share/SillyTavern/data/default-user";

  vectfoxSrc = pkgs.fetchFromGitHub {
    owner = "KritBlade";
    repo = "VectFox";
    rev = "5784a427ebeb6bae213a64740218bdf4ad05f97e";
    hash = "sha256-J3QflhhV2JgTS4Tb2lPcK9nxzbzLklgavYbIpKi7tA8=";
  };

  similharitySrc = pkgs.fetchFromGitHub {
    owner = "KritBlade";
    repo = "VectFox";
    rev = "9fdc29311ea3a5de60bf1f97536f900634254c2a";
    hash = "sha256-reQ/I65i+T8bxFvYaBUDl7ob/aqEh2cXQhC08x5/sp8=";
  };

  tpexts = cfg.extensions.thirdParty;

  extensionIndex = builtins.fromJSON (builtins.readFile (builtins.fetchurl {
    url = "https://raw.githubusercontent.com/SillyTavern/SillyTavern-Content/main/index.json";
    sha256 = "79f546c9044984e415247b1be61352980b82df9ac514754dabf799686ecd1db2";
  }));

  extensionIndexById = builtins.listToAttrs (builtins.concatMap (entry:
    if entry.type or "" == "extension" then
      let
        withoutPrefix = builtins.replaceStrings [ "https://github.com/" ] [ "" ] entry.url;
        parts = builtins.match "([^/]+)/([^/]+)" withoutPrefix;
      in
        if parts == null then [ ] else
          [{ name = entry.id; value = { owner = builtins.elemAt parts 0; repo = builtins.elemAt parts 1; }; }]
    else [ ]
  ) extensionIndex);

  mkThirdPartySrc = id: ecfg:
    if ecfg.src != null then ecfg.src
    else
      let
        info = extensionIndexById.${id} or (builtins.abort "sillytavern: extension '${id}' not in official index; set src explicitly");
      in
      pkgs.fetchFromGitHub {
        inherit (info) owner repo;
        rev = ecfg.rev;
        hash = ecfg.hash;
      };

  thirdPartySrcs = lib.filterAttrs (id: _: cfg.extensions.thirdParty.${id}.enable) (
    lib.mapAttrs' (id: ecfg:
      lib.nameValuePair id (mkThirdPartySrc id ecfg)
    ) cfg.extensions.thirdParty
  );

  thirdPartyInstallCmds = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (id: src: ''
      echo "sillytavern: installing third-party extension ${id}..."
      mkdir -p "${stUserDir}/extensions/${id}"
      cp -r ${src}/* "${stUserDir}/extensions/${id}/"
    '') thirdPartySrcs
  );

  similharityPlugin = pkgs.buildNpmPackage {
    pname = "sillytavern-plugin-similharity";
    version = "3.5.0";
    src = similharitySrc;
    npmDepsHash = "sha256-b8XfNMnoD0A3/CKnkMu64lhSddN4/ykoFCedxGk6Iv4=";
    dontNpmBuild = true;
    postPatch = ''
      cp ${./similharity-package-lock.json} package-lock.json
    '';
    installPhase = ''
      mkdir -p $out
      cp -r node_modules $out/
      cp index.js qdrant-backend.js stop-words.js package.json $out/
    '';
  };

  extDir = "public/scripts/extensions/third-party/VectFox";
  pluginDir = "plugins/similharity";

  toJsonFile = prefix: name: value:
    pkgs.writeText "sillytavern-${prefix}-${name}.json"
      (builtins.toJSON (value // { name = name; }));

  installCategory = destDir: attrset:
    lib.concatStrings (lib.mapAttrsToList
      (name: value:
        let file = toJsonFile destDir name value;
        in ''install -m 0644 ${file} "${stUserDir}/${destDir}/${name}.json"'' + "\n"
      )
      attrset);
in
{
  config = lib.mkIf cfg.enable {
    my.services.sillytavern.package = lib.mkDefault (pkgs.sillytavern.overrideAttrs (old: {
      patches = (old.patches or []) ++ [ ./connection-manager-autoconnect.patch ];
      buildInputs = (old.buildInputs or []);
      postInstall = (old.postInstall or "") + lib.optionalString vfcfg.enable ''
        echo "sillytavern: bundling VectFox extension..."
        EXT="$out/lib/node_modules/sillytavern/${extDir}"
        mkdir -p "$EXT"
        cp ${vectfoxSrc}/index.js "$EXT/"
        cp ${vectfoxSrc}/manifest.json "$EXT/"
        cp ${vectfoxSrc}/vectfox.css "$EXT/"
        for dir in backends core diagnostics providers styles ui utils; do
          cp -r ${vectfoxSrc}/$dir "$EXT/$dir"
        done

        echo "sillytavern: bundling Similharity server plugin..."
        PLUGIN="$out/lib/node_modules/sillytavern/${pluginDir}"
        mkdir -p "$PLUGIN"
        cp -r ${similharityPlugin}/node_modules "$PLUGIN/node_modules"
        chmod -R u+w "$PLUGIN/node_modules" 2>/dev/null || true
        cp ${similharityPlugin}/index.js "$PLUGIN/"
        cp ${similharityPlugin}/qdrant-backend.js "$PLUGIN/"
        cp ${similharityPlugin}/stop-words.js "$PLUGIN/"
        cp ${similharityPlugin}/package.json "$PLUGIN/"
      '';

    }));

    services.qdrant = lib.mkIf (vfcfg.enable && vfcfg.backend == "qdrant") {
      enable = true;
    };

    my.services.sillytavern.settings.enableServerPlugins = lib.mkIf vfcfg.enable (lib.mkDefault true);
    my.services.sillytavern.settings.enableServerPluginsAutoUpdate = lib.mkIf vfcfg.enable (lib.mkDefault false);

    users.users = lib.mkIf (cfg.user == "sillytavern") {
      sillytavern = {
        isSystemUser = true;
        group = cfg.group;
        description = "SillyTavern service user";
        home = homeDir;
        createHome = true;
      };
    };

    users.groups = lib.mkIf (cfg.group == "sillytavern") {
      sillytavern = { };
    };

    my.services.ollama.models = lib.mkIf (cfg.ollama.models != { })
      (lib.mkDefault cfg.ollama.models);

    my.services.sillytavern.presets.activationScript =
      pkgs.writeShellScript "sillytavern-presets" ''
        set -euo pipefail

        mkdir -p "${stUserDir}/instruct"
        mkdir -p "${stUserDir}/context"
        mkdir -p "${stUserDir}/sysprompt"
        mkdir -p "${stUserDir}/TextGen Settings"
        mkdir -p "${stUserDir}/reasoning"
        mkdir -p "${stUserDir}/Kobold AI Settings"
        mkdir -p "${stUserDir}/OpenAI Settings"
        mkdir -p "${stUserDir}/themes"
        mkdir -p "${stUserDir}/quick-replies"

        ${installCategory "instruct"               pcfg.instruct}
        ${installCategory "context"                pcfg.context}
        ${installCategory "sysprompt"              pcfg.sysprompt}
        ${installCategory "TextGen Settings"       pcfg.textgen}
        ${installCategory "reasoning"              pcfg.reasoning}
        ${installCategory "Kobold AI Settings"     pcfg.kobold}
        ${installCategory "OpenAI Settings"        pcfg.openai}
        ${installCategory "themes"                 pcfg.themes}
        ${installCategory "quick-replies"          pcfg.quickReplies}

        ${thirdPartyInstallCmds}

        chown -R ${cfg.user}:${cfg.group} \
          "${stUserDir}/instruct"               \
          "${stUserDir}/context"                \
          "${stUserDir}/sysprompt"              \
          "${stUserDir}/TextGen Settings"       \
          "${stUserDir}/reasoning"              \
          "${stUserDir}/Kobold AI Settings"     \
          "${stUserDir}/OpenAI Settings"        \
          "${stUserDir}/themes"                 \
          "${stUserDir}/quick-replies"          \
          "${stUserDir}/extensions"
      '';
  };
}
