# Main flake module — ipxe-installer project config
{ lib, config, inputs, ... }:
let
  projectModule = { lib, ... }: {
    options.project = with lib; {
      name = mkOption {
        type = types.str;
        default = "ipxe-installer";
      };
      version = mkOption {
        type = types.str;
        default = "0.1.0";
      };
      description = mkOption {
        type = types.str;
        default = "iPXE netboot installer — PXE server, Windows/NixOS unattended install";
      };
      readme = mkOption {
        type = types.str;
        default = "README.md";
      };
      requiresPython = mkOption {
        type = types.str;
        default = ">=3.12";
      };
      pythonPackage = mkOption {
        type = types.package;
        default = null;
      };
      dependencies = mkOption {
        type = types.listOf types.str;
        default = [
          "typer>=0.15"
          "jinja2>=3.1"
          "pyyaml>=6.0"
          "requests>=2.32"
          "pydantic>=2.10"
        ];
      };
      optionalDependencies = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = { };
      };
      devDependencies = mkOption {
        type = types.listOf types.str;
        default = [ "pytest>=8" "pytest-cov>=6" ];
      };
      scripts = mkOption {
        type = types.attrsOf types.str;
        default = {
          ipxe-installer = "ipxe_installer.cli:app";
        };
      };
      extraDevPackages = mkOption {
        type = types.functionTo (types.listOf types.package);
        default = pkgs: [ ];
      };
      shellEnv = mkOption {
        type = types.attrsOf types.str;
        default = { };
      };
      shellHints = mkOption {
        type = types.listOf types.str;
        default = [
          "ipxe-installer serve --help    # PXE server"
          "ipxe-installer sync-iso --help # Windows ISO download"
          "pytest                         # run tests"
          "uv add <package>               # add dependency"
        ];
      };
      mainModule = mkOption {
        type = types.str;
        default = "ipxe_installer";
      };
    };
  };
in
{
  options.uv2nix = with lib; {
    buildSystemOverrides = mkOption {
      type = types.attrsOf (types.oneOf [ (types.listOf types.str) types.attrs ]);
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

      pf = import ./pyproject.nix { inherit pkgs cfg lib; };

      prodEnv = pyEnv.basePythonSets.mkVirtualEnv "${cfg.name}-env" pyEnv.workspace.deps.default;
      testEnv = pyEnv.basePythonSets.mkVirtualEnv "${cfg.name}-test" pyEnv.workspace.deps.all;
      devEnv = pyEnv.devEnv.mkVirtualEnv "${cfg.name}-dev" pyEnv.workspace.deps.all;

      banner = lib.concatStringsSep "\n    " cfg.shellHints;
      extraPkgs = cfg.extraDevPackages pkgs;
    in
    {
      devShells.default = pkgs.mkShell {
        packages = [ testEnv pkgs.uv ] ++ extraPkgs;
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
          echo "    ${banner}"
          echo ""
        '';
      };

      devShells.bootstrap = pkgs.mkShell {
        packages = [ pkgs.uv pyEnv.python ];
        shellHook = ''
          dest="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/pyproject.toml"
          if [ ! -f "$dest" ]; then
            python3 ${pf.writerPy} ${pf.jsonData} "$dest"
            chmod 644 "$dest"
            echo "✔ Generated pyproject.toml"
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
