{ config, lib, pkgs, flake, ... }:
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

    UV_PYTHON="${cfg.pythonPackage}/bin/python${lib.versions.majorMinor cfg.pythonPackage.version}"
    UV="${cfg.uvPackage}/bin/uv"

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

  # The Jupyter server environment: Python with jupyter + extra packages.
  jupyterEnv = cfg.pythonPackage.withPackages (
    ps: [ ps.jupyter ] ++ cfg.extraPackages
  );

  # Script to initialize a template project (create pyproject.toml + uv.lock)
  # Always overwrites — templates are not meant to be edited by the user.
  initTemplateScript = pkgs.writeShellScript "jupyter-init-templates" (''
    set -euo pipefail

    UV_PYTHON="${cfg.pythonPackage}/bin/python${lib.versions.majorMinor cfg.pythonPackage.version}"
    UV="${cfg.uvPackage}/bin/uv"

    echo "jupyter-init-templates: creating ${toString (builtins.length cfg.templates)} templates"

  '' + lib.concatMapStringsSep "\n"
    (tpl:
      let
        name = tpl.name;
        desc = if tpl.description != "" then tpl.description else "Jupyter project: ${name}";
        deps = lib.concatMapStringsSep ",\n  " (p: "\"${p}\"") tpl.packages;
      in
      ''
            echo "jupyter-init-templates: setting up ${name}"
            mkdir -p "${cfg.dataDir}/${name}"

            cat > "${cfg.dataDir}/${name}/pyproject.toml" << EOF
        [project]
        name = "${name}"
        version = "0.1.0"
        description = "${desc}"
        requires-python = ">=3.12"
        dependencies = [
          ${deps}
        ]
        EOF

            echo "jupyter-init-templates: generating ${name}/uv.lock"
            UV_PYTHON="$UV_PYTHON" UV_PYTHON_DOWNLOADS="never" \
              "$UV" lock --directory "${cfg.dataDir}/${name}" || {
                echo "jupyter-init-templates: WARNING: uv lock failed for ${name}"
              }

            echo "jupyter-init-templates: ${name} ready"
      '')
    cfg.templates + ''

    echo "jupyter-init-templates: done"

    # Trigger kernel discovery now that templates are in place
    systemctl start jupyter-discover.service || true
  '');
in
{
  config = lib.mkIf cfg.enable {
    # ── Users & groups ──────────────────────────────────────────────────────
    # Only create the dedicated jupyter user/group when not overridden.
    # Precedent: chatterbox-tts/config.nix, suwayomi/config.nix
    users.groups = lib.mkIf (cfg.group == "jupyter") {
      jupyter = { };
    };

    users.users = lib.mkMerge [
      (lib.mkIf (cfg.user == "jupyter") {
        jupyter = {
          inherit (cfg) group;
          home = "/var/lib/jupyter";
          createHome = true;
          isSystemUser = true;
          useDefaultShell = true;
        };
      })
      # Add the primary user to the jupyter group so they can read/write projects.
      # Also add the jupyter service user to the users group so it can traverse
      # /home/<user>/Documents/ to reach the default dataDir.
      {
        ${flake.config.me.username}.extraGroups =
          lib.mkIf (cfg.group == "jupyter") [ "jupyter" ];
        ${cfg.user}.extraGroups =
          lib.mkIf (cfg.user == "jupyter") [ "users" ];
      }
    ];

    # ── Ensure dataDir exists ───────────────────────────────────────────────
    # dataDir is owned by primary user + jupyter group (0775) so both
    # the human user and the jupyter service can read/write notebooks.
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0775 ${flake.config.me.username} ${cfg.group} - -"
      "d ${kernelPrefix} 0775 ${cfg.user} ${cfg.group} - -"
    ];

    # ── Template project initialization ─────────────────────────────────────
    # Creates template projects on every rebuild so they're always available.
    # Runs as a systemd service after network (uv lock needs PyPI access),
    # then triggers jupyter-discover to register the new kernels.
    systemd.services.jupyter-init-templates = lib.mkIf (cfg.templates != [ ]) {
      description = "Create Jupyter template projects";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      before = [ "jupyter-discover.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Environment = "LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}";
      };
      path = [
        cfg.uvPackage
        cfg.pythonPackage
        pkgs.systemd # for systemctl
      ];
      script = ''
        # Run init as cfg.user so files are owned correctly
        ${pkgs.su}/bin/su -s ${pkgs.bash}/bin/bash ${cfg.user} -c '${initTemplateScript}'

        # Trigger kernel discovery as root
        systemctl start jupyter-discover.service || true
      '';
      unitConfig = {
        # Re-run when templates change
        ConditionPathExists = "${cfg.dataDir}";
      };
    };

    # ── Discovery oneshot ───────────────────────────────────────────────────
    systemd.services.jupyter-discover = {
      description = "Discover Jupyter projects and register kernels";
      after = [ "network.target" ] ++ lib.optionals (cfg.templates != [ ]) [ "jupyter-init-templates.service" ];
      requires = lib.optionals (cfg.templates != [ ]) [ "jupyter-init-templates.service" ];
      # No wantedBy — triggered by the path unit after init-templates creates files
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = cfg.user;
        Group = cfg.group;
        Environment = "LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}";
      };
      path = [
        cfg.uvPackage
        cfg.pythonPackage
        pkgs.bash
      ];
      script = "${discoverScript}";
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

        # NixOS 26.11 renders ExecStart lists as separate lines (one per element),
        # which systemd rejects for non-oneshot services. Use a single string instead.
        ExecStart =
          let
            base = "${jupyterEnv}/bin/jupyter notebook --no-browser"
              + " --ip=${cfg.ip} --port=${toString cfg.port}"
              + " --port-retries=0 --notebook-dir=${cfg.dataDir}";
          in
          if cfg.passwordFile != null
          then "${base} --ServerApp.password_file=${cfg.passwordFile} --ServerApp.token=''"
          else base;
      };
    };

    # ── Firewall ────────────────────────────────────────────────────────────
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
