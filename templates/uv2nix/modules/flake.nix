# Main flake module - combines shells, apps, packages, and checks
{ lib, config, inputs, ... }:
let
  # Module that defines project options
  projectModule = { lib, ... }: {
    options.project = with lib; {
      name = mkOption {
        type = types.str;
        description = "Project name (must match pyproject.toml project name)";
        default = "my-project";
      };
      version = mkOption {
        type = types.str;
        description = "Project version";
        default = "0.1.0";
      };
      description = mkOption {
        type = types.str;
        description = "Short project description";
        default = "A Python project managed with uv and Nix";
      };
      readme = mkOption {
        type = types.str;
        default = "README.md";
      };
      requiresPython = mkOption {
        type = types.str;
        description = "Python version requirement";
        default = ">=3.12";
      };
      pythonPackage = mkOption {
        type = types.package;
        description = "Python package to use";
        default = null; # Set in perSystem
      };
      dependencies = mkOption {
        type = types.listOf types.str;
        description = "Runtime dependencies";
        default = [ ];
      };
      optionalDependencies = mkOption {
        type = types.attrsOf (types.listOf types.str);
        description = "Optional dependency groups";
        default = { };
      };
      devDependencies = mkOption {
        type = types.listOf types.str;
        description = "Development dependencies (dependency-groups.dev)";
        default = [ ];
      };
      scripts = mkOption {
        type = types.attrsOf types.str;
        description = "Entry point scripts (module:function format)";
        default = { };
      };
      extraDevPackages = mkOption {
        type = types.functionTo (types.listOf types.package);
        description = "Additional packages for dev shell";
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
          "python -m my_project     # run main module"
          "pytest                   # run tests"
          "uv add <package>         # add dependency"
          "uv run <command>         # run command in venv"
        ];
      };
      mainModule = mkOption {
        type = types.str;
        description = "Main Python module to run (for app)";
        default = "my_project";
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
      # Evaluate project config
      cfg = (lib.evalModules {
        modules = [
          projectModule
          ({ config, ... }: {
            config.project.pythonPackage = pkgs.python312;
          })
        ];
        specialArgs = { inherit lib; };
      }).config.project;

      # Load Python environment (pass build system overrides separately)
      pyEnv = import ./python-env.nix {
        inherit pkgs inputs cfg;
        buildSystemOverrides = config.uv2nix.buildSystemOverrides;
      };

      # Load pyproject.toml generator
      pf = import ./pyproject.nix { inherit pkgs cfg lib; };

      # Build virtualenvs
      prodEnv = pyEnv.basePythonSets.mkVirtualEnv "${cfg.name}-env" pyEnv.workspace.deps.default;
      testEnv = pyEnv.basePythonSets.mkVirtualEnv "${cfg.name}-test" pyEnv.workspace.deps.all;
      devEnv = pyEnv.devEnv.mkVirtualEnv "${cfg.name}-dev" pyEnv.workspace.deps.all;

      # Shell banner
      banner = lib.concatStringsSep "\n    " cfg.shellHints;

      # Extra dev packages
      extraPkgs = cfg.extraDevPackages pkgs;
    in
    {
      # Development shell with full environment
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
          echo "🔧 ${cfg.name} dev shell"
          echo "    ''${banner}"
          echo ""
        '';
      };

      # Bootstrap shell for initial project setup
      devShells.bootstrap = pkgs.mkShell {
        packages = [ pkgs.uv pyEnv.python ];
        shellHook = ''
          dest="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/pyproject.toml"
          if [ ! -f "$dest" ]; then
            python3 ${pf.writerPy} ${pf.jsonData} "$dest"
            chmod 644 "$dest"
            echo "✔ Generated pyproject.toml"
            echo ""
            echo "Next steps:"
            echo "  1. Edit pyproject.toml to customize your project"
            echo "  2. Run: uv sync"
            echo "  3. Run: exit && nix develop"
          else
            echo "pyproject.toml already exists"
            echo "Run: uv sync  then  exit && nix develop"
          fi
          trap 'git add uv.lock pyproject.toml 2>/dev/null || true' EXIT
        '';
      };

      # Default package is the production environment
      packages.default = prodEnv;

      # Application runner
      apps.default = lib.mkIf (cfg.mainModule != "") {
        type = "app";
        program = lib.getExe (pkgs.writeShellApplication {
          name = cfg.name;
          runtimeInputs = [ prodEnv ];
          text = ''
            export REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
            python -m ${cfg.mainModule} "$@"
          '';
        });
      };

      # Sync pyproject.toml from Nix config
      apps.sync-pyproject = {
        type = "app";
        program = lib.getExe (pkgs.writeShellApplication {
          name = "sync-pyproject";
          runtimeInputs = [ pkgs.python3 ];
          text = ''
            dest="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/pyproject.toml"
            python3 ${pf.writerPy} ${pf.jsonData} "$dest"
            chmod 644 "$dest"
            echo "✔ Wrote $dest"
          '';
        });
      };

      # Run tests
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
