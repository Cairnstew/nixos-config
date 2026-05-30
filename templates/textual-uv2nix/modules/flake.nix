{ lib, config, inputs, ... }:
let
  projectModule = { lib, ... }: {
    options.project = with lib; {
      name = mkOption {
        type = types.str;
        description = "Project / package name";
        default = "textual-app";
      };
      pythonPackage = mkOption {
        type = types.package;
        description = "Python interpreter to use";
        default = null;
      };
      mainModule = mkOption {
        type = types.str;
        description = "Main Python module for `nix run`";
        default = "textual_app";
      };
      extraDevPackages = mkOption {
        type = types.functionTo (types.listOf types.package);
        description = "Additional Nix packages for dev shell";
        default = pkgs: [ ];
      };
      shellEnv = mkOption {
        type = types.attrsOf types.str;
        description = "Environment variables for dev shell";
        default = { };
      };
      shellHints = mkOption {
        type = types.listOf types.str;
        description = "Hints shown when entering dev shell";
        default = [
          "python -m textual_app       # run your TUI app"
          "textual run textual_app     # run with textual dev tools"
          "textual console             # open devtools console"
          "pytest                      # run tests"
          "textual colors              # preview color scheme"
          "textual keys                # interactive key tester"
        ];
      };
    };
  };
in
{
  options.uv2nix = with lib; {
    buildSystemOverrides = mkOption {
      type = types.attrsOf (types.oneOf [ (types.listOf types.str) types.attrs ]);
      description = "Build system overrides for packages with missing build deps";
      default = { };
    };
  };

  config.perSystem = { pkgs, system, ... }:
    let
      cfg = (lib.evalModules {
        modules = [
          projectModule
          ({ config, ... }: {
            config.project.pythonPackage = pkgs.python312;
          })
        ];
        specialArgs = { inherit lib; };
      }).config.project;

      pyEnv = import ./python-env.nix {
        inherit pkgs inputs cfg;
        buildSystemOverrides = config.uv2nix.buildSystemOverrides;
      };

      prodEnv = pyEnv.basePythonSets.mkVirtualEnv "${cfg.name}-env" pyEnv.workspace.deps.default;
      testEnv = pyEnv.basePythonSets.mkVirtualEnv "${cfg.name}-test" pyEnv.workspace.deps.all;
      devEnv = pyEnv.devEnv.mkVirtualEnv "${cfg.name}-dev" pyEnv.workspace.deps.all;

      banner = lib.concatStringsSep "\n    " cfg.shellHints;
      extraPkgs = cfg.extraDevPackages pkgs;
    in
    {
      devShells.default = pkgs.mkShell {
        packages = [ devEnv pkgs.uv ] ++ extraPkgs;
        env = cfg.shellEnv // {
          UV_NO_SYNC = "1";
          UV_PYTHON = "${pyEnv.python.interpreter}";
          UV_PYTHON_DOWNLOADS = "never";
        };
        shellHook = ''
          export REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
          unset PYTHONPATH
          echo ""
          echo "  ${cfg.name} — Textual TUI dev shell"
          echo "    ''${banner}"
          echo ""
        '';
      };

      packages.default = prodEnv;

      apps.default = lib.mkIf (cfg.mainModule != "") {
        type = "app";
        program = lib.getExe (pkgs.writeShellApplication {
          name = cfg.name;
          runtimeInputs = [ prodEnv ];
          text = ''
            repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
            export REPO_ROOT="$repo_root"
            python -m ${cfg.mainModule} "$@"
          '';
        });
      };

      checks.tests = pkgs.stdenv.mkDerivation {
        name = "${cfg.name}-tests";
        src = ../.;
        nativeBuildInputs = [ testEnv ];
        buildPhase = "true";
        checkPhase = ''
          export HOME="$(mktemp -d)"
          pytest --tb=short -q
        '';
        installPhase = "mkdir -p $out";
        doCheck = true;
      };
    };
}
