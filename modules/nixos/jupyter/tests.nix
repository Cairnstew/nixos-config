{ config, lib, ... }:
let
  cfg = config.my.services.jupyter;
in
{
  # ── L0: Nix Assertions ────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !cfg.enable || cfg.user != "root";
      message = "my.services.jupyter.user must not be 'root'. Jupyter should run as a dedicated service user.";
    }
    {
      assertion = !cfg.enable || cfg.ip != "";
      message = "my.services.jupyter.ip must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.dataDir != "";
      message = "my.services.jupyter.dataDir must not be empty.";
    }
  ];

  # ── L2: Smoke test ────────────────────────────────────────────────────────
  # Manual: systemctl start jupyter-smoke-test
  systemd.services.jupyter-smoke-test = lib.mkIf cfg.enable {
    description = "Smoke test for my.services.jupyter";
    serviceConfig = {
      Type = "oneshot";
      User = cfg.user;
      Group = cfg.group;
    };
    path = [
      cfg.pythonPackage
      cfg.uvPackage
    ];
    script = ''
      echo "=== jupyter smoke test ==="
      echo "dataDir: ${cfg.dataDir}"
      echo "kernelPrefix: ${cfg.dataDir}/.jupyter-kernels"
      if [ -d "${cfg.dataDir}" ]; then
        echo "PASS: dataDir exists"
      else
        echo "WARN: dataDir does not exist yet (created on first activation)"
      fi
      echo "--- Discovered projects ---"
      for d in "${cfg.dataDir}"/*/; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        [ "$name" = ".jupyter-kernels" ] && continue
        if [ -f "$d/pyproject.toml" ] && [ -f "$d/uv.lock" ]; then
          echo "  $name (valid project)"
        else
          echo "  $name (skipped: missing pyproject.toml or uv.lock)"
        fi
      done
      echo "--- Registered kernels ---"
      ls "${cfg.dataDir}/.jupyter-kernels/share/jupyter/kernels/" 2>/dev/null || echo "  (none yet)"
      echo "=== smoke test complete ==="
    '';
  };
}
