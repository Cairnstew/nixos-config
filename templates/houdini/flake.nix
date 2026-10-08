{
  description = "Houdini project — runs against the Houdini installed on this system";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem =
        { pkgs, ... }:
        let
          # ── Why Houdini is not a flake input ─────────────────────────────
          # SideFX Houdini is proprietary: it cannot be fetched by Nix and is
          # not in nixpkgs.  This project uses the Houdini already installed on
          # the host by nixos-config's `my.programs.houdini` module — a
          # `houdini-nix` build exposed as `houdini`/`hython` wrappers in
          # /run/current-system/sw/bin, with `HFS` pointing at the runtime.
          #
          # `nix develop` and `nix run` inherit the ambient PATH, so the system
          # wrappers are found by name.  Do NOT add "$HFS/bin" to PATH: that
          # bypasses the module's FHS launcher (dsolib ordering, Qt/QML setup,
          # Vulkan ICD) and Houdini crashes on startup.
          houdiniBin = "houdini";
          hythonBin = "hython";

          checkHostHoudini = ''
            if ! command -v ${hythonBin} >/dev/null 2>&1; then
              echo "error: '${hythonBin}' was not found on PATH." >&2
              echo "Enable my.programs.houdini in your NixOS config and rebuild," >&2
              echo "then re-enter this shell." >&2
              exit 1
            fi
            if [ -z "''${HFS:-}" ]; then
              echo "warning: HFS is not set — Houdini may fail to find its runtime." >&2
            fi
          '';

          # Project-local Houdini environment.  $JOB is the project root and
          # $HIP where scene files live; ./houdini is exposed as a Houdini
          # package ('&' expands to Houdini's default search path).
          projectEnv = ''
            export JOB="$PWD"
            export HIP="$PWD/hip"
            export HOUDINI_PATH="$PWD/houdini:&"
            export PYTHONDONTWRITEBYTECODE=1
          '';

          # Build a `nix run` app: resolve the project root from git (so it
          # works from any subdirectory), set the project env, verify the host
          # Houdini, then run the given command.
          mkApp =
            name: text:
            {
              type = "app";
              program = "${pkgs.writeShellApplication {
                inherit name;
                runtimeInputs = [
                  pkgs.coreutils
                  pkgs.git
                ];
                text = ''
                  set -euo pipefail
                  cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
                  ${projectEnv}
                  ${checkHostHoudini}
                  ${text}
                '';
              }}/bin/${name}";
            };

          # Launch the Houdini GUI with this project's environment.
          houdiniApp = mkApp "houdini-project" ''
            exec ${houdiniBin} "$@"
          '';

          # Run a Python script inside Houdini's interpreter.
          hythonApp = mkApp "houdini-project-hython" ''
            exec ${hythonBin} "$@"
          '';
        in
        {
          devShells.default = pkgs.mkShell {
            name = "houdini-project";

            packages = with pkgs; [
              python3 # for out-of-Houdini tooling / linting
              ruff
            ];

            shellHook = ''
              ${projectEnv}
              ${checkHostHoudini}
              echo "Houdini project shell"
              echo "  hython:    $(command -v ${hythonBin} || echo 'not found')"
              echo "  Houdini:   ''${HOUDINI_MAJOR_RELEASE:-unknown}"
              echo "  JOB:       $JOB"
              echo "  HIP:       $HIP"
              echo ""
              echo "  houdini    launch the GUI on this project   (nix run .#houdini)"
              echo "  hython     run Python inside Houdini        (nix run .#hython -- script.py)"
            '';
          };

          apps = {
            # `nix run` (no attribute) launches the GUI; `.#houdini` is the
            # same app named explicitly.
            default = houdiniApp;
            houdini = houdiniApp;

            # Run a Python script inside Houdini's interpreter:
            #   nix run .#hython -- scripts/example.py
            hython = hythonApp;
          };
        };
    };
}
