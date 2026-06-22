{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.chatterbox-tts;
  stateDir = cfg.stateDir;

  yamlFmt = pkgs.formats.yaml { };

  defaultConfigYaml = yamlFmt.generate "chatterbox-tts-default-config.yaml" {
    server = {
      host = "127.0.0.1";
      port = 8004;
      use_ngrok = false;
      use_auth = false;
      auth_username = "user";
      auth_password = "password";
      log_file_path = "${stateDir}/logs/tts_server.log";
      log_file_max_size_mb = 10;
      log_file_backup_count = 5;
      ssl_certfile = null;
      ssl_keyfile = null;
    };
    model = {
      repo_id = "chatterbox-turbo";
    };
    tts_engine = {
      device = "cpu";
      predefined_voices_path = "${stateDir}/voices";
      reference_audio_path = "${stateDir}/reference_audio";
      default_voice_id = "";
    };
    paths = {
      model_cache = "${stateDir}/model_cache";
      output = "${stateDir}/outputs";
    };
    generation_defaults = {
      temperature = 0.8;
      exaggeration = 0.5;
      cfg_weight = 0.5;
      seed = 0;
      speed_factor = 1.0;
      language = "en";
    };
    audio_output = {
      format = "wav";
      sample_rate = 24000;
      max_reference_duration_sec = 30;
      save_to_disk = false;
    };
    ui = {
      title = "Chatterbox TTS Server";
      show_language_select = true;
      max_predefined_voices_in_dropdown = 20;
    };
    debug = {
      save_intermediate_audio = false;
    };
  };

  seedScript = pkgs.writeShellScript "chatterbox-tts-seed" ''
    set -euo pipefail

    CONFIG="${stateDir}/config.yaml"

    # Seed default config.yaml on first boot
    if [ ! -f "$CONFIG" ]; then
      install -m 0640 ${defaultConfigYaml} "$CONFIG"
      echo "chatterbox-tts: seeded default config.yaml"
    fi

    # Merge extraConfig overrides (if any)
    ${lib.optionalString (cfg.extraConfig != { }) ''
      OVERRIDES="${yamlFmt.generate "chatterbox-overrides.yaml" cfg.extraConfig}"
      ${pkgs.yq-go}/bin/yq eval-all 'select(fi == 0) * select(fi == 1)' "$CONFIG" "$OVERRIDES" \
        > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
      echo "chatterbox-tts: merged extraConfig overrides"
    ''}

    # Override device, model, host, port from module options
    ${pkgs.yq-go}/bin/yq eval "
      .tts_engine.device = \"${cfg.backend}\" |
      .model.repo_id = \"${cfg.model}\" |
      .server.host = \"${cfg.host}\" |
      .server.port = ${toString cfg.port}
    " "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

    # Ensure runtime directories exist
    mkdir -p "${stateDir}/voices" "${stateDir}/reference_audio" \
             "${stateDir}/outputs" "${stateDir}/logs" "${stateDir}/model_cache"
    chown -R ${cfg.user}:${cfg.group} "${stateDir}"
  '';

  probeScript = pkgs.writeShellScript "chatterbox-tts-probe" ''
    echo "[chatterbox-tts probe] waiting for API on ${cfg.host}:${toString cfg.port}..."
    for i in $(${pkgs.coreutils}/bin/seq 1 30); do
      if ${pkgs.curl}/bin/curl -sf http://${cfg.host}:${toString cfg.port}/api/ui/initial-data > /dev/null 2>&1; then
        echo "[chatterbox-tts probe] API reachable (attempt $i)"
        exit 0
      fi
      sleep 1
    done
    echo "[chatterbox-tts probe] FAIL: API not reachable after 30s" >&2
    exit 1
  '';
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.chatterbox-tts = {
      description = "Chatterbox TTS Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        HF_HOME = "${stateDir}/model_cache";
        TTS_BF16 = "off";
        LD_LIBRARY_PATH = lib.makeLibraryPath (
          with pkgs; [ stdenv.cc.cc.lib zlib zstd libsndfile glibc ]
        );
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        TimeoutStartSec = "10min";
        WorkingDirectory = stateDir;

        StateDirectory = baseNameOf stateDir;
        StateDirectoryMode = "0750";

        ExecStartPre = "+${seedScript}";
        ExecStart = "${lib.getExe cfg.package} --host ${cfg.host} --port ${toString cfg.port}";
        ExecStartPost = "+${probeScript}";

        Restart = "on-failure";
        RestartSec = "5s";

        # Hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHome = false;
        ProtectSystem = "strict";
        ReadWritePaths = [ stateDir ];
        CapabilityBoundingSet = [ "CAP_CHOWN" "CAP_DAC_OVERRIDE" ];
        LockPersonality = true;
        MemoryDenyWriteExecute = false;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      };
    };
  };
}
