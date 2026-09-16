{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.jupyter;

  # Shared prefix where all discovered kernels are installed.
  # Each project's kernel lands in <kernelPrefix>/share/jupyter/kernels/<name>/kernel.json.
  kernelPrefix = "${cfg.dataDir}/.jupyter-kernels";

  # The Jupyter server discovers kernels via JUPYTER_PATH.
  # This must point at directories containing share/jupyter/kernels/.
  jupyterPath = kernelPrefix;

  # Discovery script: iterate dataDir subdirectories, sync venvs, register kernels.
  discoverScript = pkgs.writeShellScript "jupyter-discover" ''
    set -euo pipefail

    UV_PYTHON="${cfg.pythonPackage}/bin/python${lib.versions.minor (lib.versions.majorMinor cfg.pythonPackage.version)}"
    UV="${cfg.uvPackage}/bin/uv"
    IPYKERNEL="${cfg.pythonPackage}/bin/python${lib.versions.minor (lib.versions.majorMinor cfg.pythonPackage.version)} -m ipykernel"

    mkdir -p "${kernelPrefix}"

    echo "jupyter-discover: scanning ${cfg.dataDir}/*/"

    for projectDir in "${cfg.dataDir}"/*/; do
      [ -d "$projectDir" ] || continue

      name="$(basename "$projectDir")"

      # Skip the kernel prefix directory itself
      [ "$name" = ".jupyter-kernels" ] && continue

      # Require both pyproject.toml and uv.lock
      if [ ! -f "$projectDir/pyproject.toml" ] || [ ! -f "$projectDir/uv.lock" ]; then
        echo "jupyter-discover: skipping $name (no pyproject.toml + uv.lock)"
        continue
      fi

      echo "jupyter-discover: syncing $name"

      # Create/update the venv using the Nix-pinned interpreter.
      # --frozen: fail if uv.lock is missing or incompatible (no network).
      UV_PYTHON="$UV_PYTHON" UV_PYTHON_DOWNLOADS="never" \
        "$UV" sync --frozen --directory "$projectDir" || {
          echo "jupyter-discover: WARNING: uv sync failed for $name, skipping"
          continue
        }

      # Register the kernel under the shared prefix.
      # --prefix ensures kernels don't collide and land in kernelPrefix/share/jupyter/kernels/.
      "$projectDir/.venv/bin/python" -m ipykernel install \
        --name "$name" \
        --prefix "${kernelPrefix}" \
        --display-name "Python 3 ($name)" || {
          echo "jupyter-discover: WARNING: ipykernel install failed for $name, skipping"
          continue
        }

      echo "jupyter-discover: registered kernel for $name"
    done

    echo "jupyter-discover: done"
  '';

  # The Jupyter server package with extra packages.
  jupyterEnv = cfg.jupyterPackage.pythonModule.pkgs.withPackages (
    ps: [ cfg.jupyterPackage ] ++ cfg.extraPackages
  );
in
{
  config = lib.mkIf cfg.enable {
    # ── Users & groups ──────────────────────────────────────────────────────
    users.groups.jupyter = { };
    users.users.jupyter = {
      inherit (cfg) group;
      home = "/var/lib/jupyter";
      createHome = true;
      isSystemUser = true;
      useDefaultShell = true;
    };

    # ── Ensure dataDir exists ───────────────────────────────────────────────
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0775 ${cfg.user} ${cfg.group} - -"
      "d ${kernelPrefix} 0775 ${cfg.user} ${cfg.group} - -"
    ];

    # ── Discovery oneshot ───────────────────────────────────────────────────
    systemd.services.jupyter-discover = {
      description = "Discover Jupyter projects and register kernels";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = cfg.user;
        Group = cfg.group;
      };
      path = [
        cfg.uvPackage
        cfg.pythonPackage
        pkgs.bash
      ];
      script = "${discoverScript}";
    };

    # ── Path unit: trigger discovery on new directories ─────────────────────
    systemd.paths.jupyter-discover = {
      description = "Watch ${cfg.dataDir} for new project directories";
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        PathModified = cfg.dataDir;
        PathExists = cfg.dataDir;
        Unit = "jupyter-discover.service";
      };
    };

    # ── Jupyter server ──────────────────────────────────────────────────────
    systemd.services.jupyter = {
      description = "Jupyter notebook server";
      after = [
        "network.target"
        "jupyter-discover.service"
      ];
      wants = [ "jupyter-discover.service" ];
      wantedBy = [ "multi-user.target" ];

      path = [
        cfg.pythonPackage
        pkgs.bash
      ];

      environment = {
        JUPYTER_PATH = jupyterPath;
      };

      serviceConfig = {
        Restart = "always";
        RestartSec = 5;
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = "~";

        ExecStart = lib.concatStringsSep " " [
          "${jupyterEnv}/bin/jupyter"
          "notebook"
          "--no-browser"
          "--ip=${cfg.ip}"
          "--port=${toString cfg.port}"
          "--port-retries=0"
          "--notebook-dir=${cfg.dataDir}"
        ];
      };
    };

    # ── Firewall ────────────────────────────────────────────────────────────
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
