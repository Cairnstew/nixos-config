{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.chatterbox-tts;
  stateDir = cfg.stateDir;
in
{
  # ── L0: Nix Assertions ──────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !cfg.enable || cfg.port > 0;
      message = "my.services.chatterbox-tts.port must be a valid port number (> 0).";
    }
    {
      assertion = !cfg.enable || cfg.port < 65536;
      message = "my.services.chatterbox-tts.port must be less than 65536.";
    }
    {
      assertion = !cfg.enable || cfg.user != "";
      message = "my.services.chatterbox-tts.user must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.group != "";
      message = "my.services.chatterbox-tts.group must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.stateDir != "";
      message = "my.services.chatterbox-tts.stateDir must not be empty.";
    }
    {
      assertion = !cfg.enable || builtins.elem cfg.backend [ "cpu" "cuda" "rocm" ];
      message = "my.services.chatterbox-tts.backend must be one of: cpu, cuda, rocm.";
    }
    {
      assertion = !cfg.enable || builtins.elem cfg.model [ "chatterbox" "chatterbox-turbo" "chatterbox-multilingual" ];
      message = "my.services.chatterbox-tts.model must be one of: chatterbox, chatterbox-turbo, chatterbox-multilingual.";
    }
  ];

  # ── L2: Smoke Test Service ────────────────────────────────────────────────────
  systemd.services.chatterbox-tts-smoke-test = lib.mkIf cfg.enable {
    description = "Smoke test for Chatterbox TTS Server";
    after = [ "chatterbox-tts.service" ];
    requires = [ "chatterbox-tts.service" ];

    serviceConfig.Type = "oneshot";

    script = ''
      set -euo pipefail
      FAILED=0
      TOTAL=0
      PASSED=0

      section() {
        TOTAL=$((TOTAL + 1))
        echo ""
        echo "═══ [$TOTAL] $1 ═══"
      }

      pass() {
        echo "  PASS: $1"
        PASSED=$((PASSED + 1))
      }

      fail() {
        echo "  FAIL: $1" >&2
        FAILED=$((FAILED + 1))
      }

      # ── [1] Service Unit ────────────────────────────────────────────────────
      section "Service Unit"

      if systemctl list-unit-files chatterbox-tts.service > /dev/null 2>&1; then
        pass "chatterbox-tts.service unit exists"
      else
        fail "chatterbox-tts.service unit not found"
      fi

      if systemctl is-enabled chatterbox-tts.service > /dev/null 2>&1; then
        pass "chatterbox-tts.service is enabled"
      else
        fail "chatterbox-tts.service is not enabled"
      fi

      if systemctl is-active chatterbox-tts.service > /dev/null 2>&1; then
        pass "chatterbox-tts.service is active"
      else
        echo "  INFO: chatterbox-tts.service is not active (may need start)"
      fi

      # ── [2] State Directory Structure ──────────────────────────────────────
      section "State Directory Structure"

      DIRS=(
        "${stateDir}"
        "${stateDir}/voices"
        "${stateDir}/reference_audio"
        "${stateDir}/outputs"
        "${stateDir}/logs"
        "${stateDir}/model_cache"
      )
      for d in "''${DIRS[@]}"; do
        if [ -d "$d" ]; then
          pass "Directory exists: $d"
          PERMS=$(stat -c '%a' "$d")
          OWNER=$(stat -c '%U:%G' "$d")
          echo "  INFO: Permissions $PERMS, Owner $OWNER"
        else
          fail "Directory missing: $d"
        fi
      done

      # ── [3] config.yaml ──────────────────────────────────────────────────────
      section "config.yaml"

      CONFIG="${stateDir}/config.yaml"
      if [ -f "$CONFIG" ]; then
        pass "config.yaml exists"
        SIZE=$(stat -c%s "$CONFIG")
        if [ "$SIZE" -gt 10 ]; then
          pass "config.yaml size looks valid ($SIZE bytes)"
        else
          fail "config.yaml too small ($SIZE bytes)"
        fi
        if ${pkgs.yq-go}/bin/yq eval '.' "$CONFIG" > /dev/null 2>&1; then
          pass "config.yaml is valid YAML"
        else
          fail "config.yaml is not valid YAML"
        fi
      else
        fail "config.yaml does not exist"
      fi

      # ── [4] API Reachability ─────────────────────────────────────────────────
      section "API Reachability"

      if systemctl is-active chatterbox-tts.service > /dev/null 2>&1; then
        echo "Checking API on http://${cfg.host}:${toString cfg.port}/api/ui/initial-data ..."
        if ${pkgs.curl}/bin/curl -sf http://${cfg.host}:${toString cfg.port}/api/ui/initial-data > /dev/null 2>&1; then
          pass "Chatterbox TTS API reachable on port ${toString cfg.port}"
        else
          fail "Chatterbox TTS API unreachable on port ${toString cfg.port}"
        fi

        # Check OpenAI-compatible voice listing endpoint
        if ${pkgs.curl}/bin/curl -sf http://${cfg.host}:${toString cfg.port}/v1/audio/voices > /dev/null 2>&1; then
          pass "/v1/audio/voices endpoint reachable"
        else
          echo "  INFO: /v1/audio/voices not reachable (may need model loaded)"
        fi
      else
        echo "  INFO: chatterbox-tts.service not active — skipping API reachability check"
      fi

      # ── Summary ──────────────────────────────────────────────────────────────
      echo ""
      echo "═══ Chatterbox TTS Smoke Test Complete: $TOTAL sections, $PASSED passed, $FAILED failed ═══"
      if [ "$FAILED" -gt 0 ]; then
        exit 1
      fi
    '';
  };
}
