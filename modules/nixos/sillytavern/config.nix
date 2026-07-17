{ config, lib, pkgs, ... }:
let
  ucfg = config.services.sillytavern;

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

  # Ollama model auto-pull via docker exec
  modelPullCmds =
    if ucfg.enable then
      lib.concatStringsSep "\n"
        (lib.mapAttrsToList
          (_: profile:
            let model = profile.model or "";
            in lib.optionalString (model != "") ''
              echo "sillytavern: pulling model ${model} via ollama..."
              ${pkgs.docker}/bin/docker exec ollama ollama pull ${lib.escapeShellArg model} \
                || echo "sillytavern: WARN: failed to pull ${model}"
            ''
          )
          ucfg.connectionProfiles)
    else
      "";

  ollamaPullScript = pkgs.writeShellScript "sillytavern-ollama-pull" ''
    ${modelPullCmds}
  '';

  # VectFox is bundled into the package but hidden by the BindPaths mount
  # that overlays the third-party dir. Copy it into the extensions dir
  # so ST can see it.
  copyVectfoxScript = pkgs.writeShellScript "sillytavern-copy-vectfox" ''
    set -e
    EXT_DIR="/var/lib/SillyTavern/extensions/VectFox"
    PKG_VECTFOX="${ucfg.package}/lib/node_modules/sillytavern/${extDir}"
    if [ -d "$PKG_VECTFOX" ] && [ ! -d "$EXT_DIR" ]; then
      mkdir -p "$EXT_DIR"
      cp -r "$PKG_VECTFOX"/* "$EXT_DIR/"
      chown -R ${ucfg.user}:${ucfg.group} "$EXT_DIR" 2>/dev/null || true
      echo "sillytavern: copied VectFox to extensions directory"
    fi
  '';
in
{
  config = lib.mkIf ucfg.enable {
    # Package override: bundle VectFox, Similharity, and autoconnect patch
    services.sillytavern.package = lib.mkDefault (pkgs.sillytavern.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./connection-manager-autoconnect.patch ];
      postInstall = (old.postInstall or "") + ''
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

        echo "sillytavern: bundling Resemble.ai TTS provider..."
        TTS="$out/lib/node_modules/sillytavern/public/scripts/extensions/tts"
        cp ${./resemble.js} "$TTS/resemble.js"
        chmod 644 "$TTS/resemble.js"
        # Patch index.js to import and register the Resemble provider
        if grep -q "ResembleTtsProvider" "$TTS/index.js"; then
          echo "sillytavern: Resemble provider already registered, skipping patch"
        else
          sed -i "s|^import { VolcengineTtsProvider }|import { ResembleTtsProvider } from './resemble.js';\nimport { VolcengineTtsProvider }|" "$TTS/index.js"
          sed -i "s|^    Volcengine: VolcengineTtsProvider,\$|    Resemble: ResembleTtsProvider,\n    Volcengine: VolcengineTtsProvider,|" "$TTS/index.js"
          echo "sillytavern: patched index.js for Resemble TTS provider"
        fi

        echo "sillytavern: adding Resemble.ai server endpoint..."
        SPEECH="$out/lib/node_modules/sillytavern/src/endpoints/speech.js"
        if grep -q "resemble" "$SPEECH"; then
          echo "sillytavern: Resemble endpoint already exists, skipping patch"
        else
          cat ${./resemble-server-endpoint.js} >> "$SPEECH"
          echo "sillytavern: patched speech.js for Resemble server endpoint"
        fi
      '';
    }));

    # Enable server plugins (needed for VectFox/Similharity)
    services.sillytavern.enableServerPlugins = lib.mkDefault true;
    services.sillytavern.enableServerPluginsAutoUpdate = lib.mkDefault false;

    # Ollama model auto-pull on startup
    systemd.services.sillytavern.serviceConfig.ExecStartPre =
      lib.mkAfter [ "+${ollamaPullScript}" "+${copyVectfoxScript}" ];

    # Disable extension auto-update — extensions are managed declaratively
    # and the Nix store is read-only, so git pull fails.
    services.sillytavern.extensions.autoUpdate = lib.mkDefault false;

    # Register with reverse proxy
    my.services.proxy.upstreams.sillytavern = {
      port = ucfg.port;
      displayName = "SillyTavern";
      path = "/sillytavern/";
      # Caddy's handle_path strips /sillytavern prefix automatically,
      # so no htmlBase / subs_filter needed. WebSocket is auto-detected.
      # Root-relative SPA paths are proxied via extraLocations below.
      extraLocations = [
        # SPA frontend assets
        ''
        handle /assets/* {
          reverse_proxy 127.0.0.1:${toString ucfg.port}
        }
        ''
        # Stylesheets
        ''
        handle /css/* {
          reverse_proxy 127.0.0.1:${toString ucfg.port}
        }
        ''
        # JavaScript scripts
        ''
        handle /scripts/* {
          reverse_proxy 127.0.0.1:${toString ucfg.port}
        }
        ''
        # REST API
        ''
        handle /api/* {
          reverse_proxy 127.0.0.1:${toString ucfg.port}
        }
        ''
        # User content (avatars, uploads)
        ''
        handle /user/* {
          reverse_proxy 127.0.0.1:${toString ucfg.port}
        }
        ''
        # Character card data
        ''
        handle /characters/* {
          reverse_proxy 127.0.0.1:${toString ucfg.port}
        }
        ''
        # Chat history
        ''
        handle /chats/* {
          reverse_proxy 127.0.0.1:${toString ucfg.port}
        }
        ''
        # Background images
        ''
        handle /backgrounds/* {
          reverse_proxy 127.0.0.1:${toString ucfg.port}
        }
        ''
        # Notification sounds
        ''
        handle /sounds/* {
          reverse_proxy 127.0.0.1:${toString ucfg.port}
        }
        ''
      ];
    };
  };
}
