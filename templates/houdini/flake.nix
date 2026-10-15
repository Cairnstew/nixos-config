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

          # ── Python type stubs for `hou` ──────────────────────────────────
          # `hou` is a compiled SWIG extension.  The *real* `hou.py` that
          # Houdini ships is 124k lines of SWIG boilerplate whose signatures
          # use C pointer types (`def pwd() -> "HOM_Node *"`), which no
          # type-checker can resolve — so every `hou` call comes back
          # `Unknown` and hover/autocomplete report nothing useful.
          #
          # `types-houdini` (LumaPictures/cg-stubs) publishes cleaned-up
          # `.pyi` stubs generated from a real Houdini install, where the same
          # signature reads `def pwd() -> Node`.  It is a stub-only
          # (PEP 561) wheel whose entire layout is
          #
          #     hou-stubs/__init__.pyi    # ~97k annotated lines
          #
          # so all we need is the directory that *contains* `hou-stubs` —
          # exactly what pyright's `stubPath` expects.  Not in nixpkgs, so it
          # is pinned here; bump `version` and `hash` together.
          #
          # The stubs are *not* self-contained: `hou-stubs/__init__.pyi` starts
          # with `from houcppportion import *`, so `.hou-libs` (below) still has
          # to be on the path.
          houdiniTypeStubs = pkgs.runCommand "houdini-type-stubs"
            {
              nativeBuildInputs = [ pkgs.unzip ];
            }
            ''
              mkdir -p "$out"
              ${pkgs.unzip}/bin/unzip -q ${pkgs.fetchurl {
                url = "https://files.pythonhosted.org/packages/ee/ff/5f09bda5c91969e91fb8d71226f667ac2b9756125e97811ad912a240861d/types_houdini-21.0.512.3-py2.py3-none-any.whl";
                hash = "sha256-+vLht7qD8GJ1N4B439mjP5MJeKc+OMYCxqXLd+zfLg0=";
              }}
              cp -r hou-stubs "$out/hou-stubs"

              # Inside Houdini, `hou` is already imported in every Python SOP,
              # wrangle, shelf tool and `hou.session` — scripts use it without
              # an `import hou` line.  A `__builtins__.pyi` that re-imports it
              # teaches the type-checker the same, so those files stop
              # reporting `"hou" is not defined`.  It is purely additive:
              # `print`/`len`/`str`/... still resolve through the real
              # typeshed builtins, and an explicit `import hou` is unaffected.
              printf '%s\n' 'import hou as hou' > "$out/__builtins__.pyi"
            '';

          # Point .hou-libs at Houdini's own Python library directory so
          # editors/pyright can resolve `import hou` against the real SWIG
          # module.  The directory is named after the bundled interpreter
          # (python3.13libs) and lives under a content-addressed store path,
          # both of which change on upgrade -- so resolve it by glob and
          # refresh the symlink whenever its target has gone stale.
          # Set `warn` to also report a missing Houdini runtime.
          linkHouLibs =
            warn:
            ''
              hou_libs=$(echo "''${HFS:-}"/houdini/python3.*libs 2>/dev/null)
              if [ -d "$hou_libs" ] && [ ! -e .hou-libs/hou.py ]; then
                ln -sfn "$hou_libs" .hou-libs
              fi
            ''
            + pkgs.lib.optionalString warn ''
              if [ ! -e .hou-libs/hou.py ]; then
                echo "warning: could not find Houdini's python libs under ''${HFS:-<unset>}" >&2
                echo "         'import hou' will not resolve in your editor." >&2
              fi
            '';

          # `pxr` (USD) does *not* live under houdini/python3.XXlibs — it sits
          # in Houdini's own site-packages, alongside ~150 unrelated
          # third-party packages (aiohttp, attrs, bcrypt, build, certifi,
          # cffi, click, …).  Adding that whole directory to `extraPaths`
          # would shadow the nixpkgs interpreter's packages and slow indexing
          # for no benefit, so link `pxr` alone into `.hou-site/`.
          #
          # Note this buys module resolution only: `pxr/__init__.py` is a
          # one-line `__all__` and every real API lives in compiled
          # `_usd.so` / `_tf.so`, so attribute access on `pxr` types stays
          # "partially unknown".  (There is a separate `types-usd` package
          # from the same cg-stubs project if that ever becomes limiting.)
          linkHouSite =
            warn:
            ''
              hou_site=$(echo "''${HFS:-}"/python/lib/python3.*/site-packages 2>/dev/null)
              if [ -d "$hou_site/pxr" ] && [ ! -e .hou-site/pxr/__init__.py ]; then
                rm -rf .hou-site
                mkdir -p .hou-site
                ln -sfn "$hou_site/pxr" .hou-site/pxr
              fi
            ''
            + pkgs.lib.optionalString warn ''
              if [ ! -e .hou-site/pxr/__init__.py ]; then
                echo "warning: could not find Houdini's pxr (USD) modules under ''${HFS:-<unset>}" >&2
                echo "         'import pxr' will not resolve in your editor." >&2
              fi
            '';

          # Symlink the `hou` type stubs in at `.stubs`.  Unlike `.hou-libs`
          # this target is a pinned, reproducible nix store path -- it cannot
          # go stale, so it is refreshed unconditionally rather than guarded.
          linkTypeStubs = ''
            if [ "$(readlink .stubs 2>/dev/null)" != "${houdiniTypeStubs}" ]; then
              rm -rf .stubs
              ln -s "${houdiniTypeStubs}" .stubs
            fi
          '';

          # Everything an editor (and `nix run .#pyright`) needs before a
          # type-check can resolve `hou`.
          setupEditor = ''
            ${linkHouLibs false}
            ${linkHouSite false}
            ${linkTypeStubs}
          '';

          # Pin the type-checker to Houdini's *bundled* interpreter rather
          # than whatever `python3` happens to be first on PATH.
          #
          # pyright reads `pythonVersion` but still resolves imports through
          # the first `python3` it finds, which on NixOS is nixpkgs'
          # (e.g. 3.14) -- so a bare `pythonVersion` leaves it mixing a 3.13
          # language level with a 3.14 standard library.  Houdini's own
          # `pythonVersion` is therefore derived from the same glob as the
          # symlink above and written into pyrightconfig.json.
          #
          # The committed pyrightconfig.json is the fallback for the case
          # where the shell hook has not run yet (an editor opened before
          # `nix develop`); this regenerates it in place with the real
          # version.  Editors pick it up on their next file save.
          syncPyrightConfig = ''
            hou_libs=$(readlink .hou-libs 2>/dev/null || true)
            py_ver=$(echo "$hou_libs" | sed -n 's|.*/python3\.\([0-9]*\)libs.*|\1|p')
            if [ -n "$py_ver" ] && [ -f pyrightconfig.json ]; then
              if ! grep -q "\"pythonVersion\": \"3.$py_ver\"" pyrightconfig.json; then
                sed -i.bak "s/\"pythonVersion\": \"[0-9.]*\"/\"pythonVersion\": \"3.$py_ver\"/" pyrightconfig.json
                rm -f pyrightconfig.json.bak
                echo "  pinned pythonVersion to 3.$py_ver (Houdini's bundled interpreter)"
              fi
            fi
          '';

          # `.opencode/opencode.json` cannot name its own flake at commit
          # time — a scaffolded project's absolute path is only known once it
          # exists — and that path *must* be absolute: opencode spawns its MCP
          # children from the web daemon's cwd (often `~/nixos-config`, never
          # the project), so a `.#houdini-mcp` ref fails there with
          # "could not find a flake.nix file".
          #
           # The project root is therefore resolved at shell-entry time, from
           # git's toplevel like `mkApp` does, rather than captured as a
           # build-time store path (which would also be GC-able and would freeze
           # the app at whatever revision was current when the shell opened).
           # Written idempotently so it does not dirty the tree on every entry.
           #
           # When editing the printf below, note the env key is **`environment`**,
           # never `env`: opencode validates each MCP block against
           # `McpLocalConfig` and silently drops unknown keys, so a `"env"` block
           # loses `MCP_TRANSPORT=stdio`, the server falls back to HTTP on :3055
           # and opencode reports only `status=failed` after a 30 s timeout.
           syncOpencodeConfig = ''
            mkdir -p .opencode
            proj="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            {
              printf '%s\n' \
                '{' \
                '  "$schema": "https://opencode.ai/config.json",' \
                '  "mcp": {' \
                '    "houdini": {' \
                '      "type": "local",' \
                "      \"command\": [\"/run/current-system/sw/bin/nix\", \"run\", \"$proj#houdini-mcp\"]," \
                '      "environment": {' \
                '        "HOUDINI_HOST": "localhost",' \
                '        "HOUDINI_PORT": "18811",' \
                '        "MCP_TRANSPORT": "stdio"' \
                '      },' \
                '      "enabled": true' \
                '    }' \
                '  }' \
                '}'
            } > .opencode/opencode.json.new
            if cmp -s .opencode/opencode.json.new .opencode/opencode.json; then
              rm -f .opencode/opencode.json.new
            else
              mv .opencode/opencode.json.new .opencode/opencode.json
              echo "  .opencode/opencode.json: MCP server pinned to \$proj"
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

          # Type-check with `hou` resolved against Houdini's own module.
          # Targets default to the whole project; override like any pyright
          # invocation: nix run .#pyright -- scripts/foo.py
          pyrightApp =
            let
              bin = "${pkgs.pyright}/bin/pyright";
            in
            mkApp "houdini-project-pyright" ''
              ${setupEditor}
              ${syncPyrightConfig}
              if [ $# -eq 0 ]; then
                exec ${bin} scripts
              else
                exec ${bin} "$@"
              fi
            '';

          # Same, but with basedpyright (what Zed's Python extension runs, so
          # the editor and this app see the same diagnostics).
          basedpyrightApp =
            let
              bin = "${pkgs.basedpyright}/bin/basedpyright";
            in
            mkApp "houdini-project-basedpyright" ''
              ${setupEditor}
              ${syncPyrightConfig}
              if [ $# -eq 0 ]; then
                exec ${bin} scripts
              else
                exec ${bin} "$@"
              fi
            '';

          # ── houdini-mcp: MCP server for Houdini ────────────────────────
          # An MCP server (43 tools) that lets an AI assistant inspect and
          # drive the *running* Houdini session over hrpyc, plus fetch SideFX
          # documentation — wired up for this project by `.opencode/opencode.json`.
          #
          # Two things stop this simply being `python3Packages.houdini-mcp`:
          #   1. upstream (github.com/oculairmedia/houdini-mcp) is not in
          #      nixpkgs, so it is built from source here and pinned to a
          #      commit — bump `rev`/`sha256` together when updating.
          #   2. hrpyc (Houdini's RPyC server) speaks RPyC **5.x only**: the
          #      6.x line changed the protocol, so rpyc 5.3.1 is built from
          #      PyPI rather than taking `python3Packages.rpyc` (6.x).
          rpyc5 = pkgs.python3Packages.buildPythonPackage rec {
            pname = "rpyc";
            version = "5.3.1";
            src = pkgs.fetchurl {
              url = "https://files.pythonhosted.org/packages/source/r/rpyc/rpyc-${version}.tar.gz";
              sha256 = "0lmzrxc6f0sg6k0yvi6f2z44dkhiankdadv44sp1ibwzhxs328zj";
            };
            pyproject = true;
            build-system = with pkgs.python3Packages; [ hatchling ];
            dependencies = with pkgs.python3Packages; [ plumbum ];
          };

          houdiniMcp = pkgs.python3Packages.buildPythonPackage rec {
            pname = "houdini-mcp";
            version = "1.0.0";
            src = pkgs.fetchFromGitHub {
              owner = "oculairmedia";
              repo = "houdini-mcp";
              rev = "d7c2e0ea3e5711f417881d04d134c741c7415231";
              sha256 = "sha256-g7qiJEKaO1EKyK5IP9srbz02LnLNoJK2tiAmQLwsrMA=";
            };
            pyproject = true;
            build-system = with pkgs.python3Packages; [ setuptools wheel ];
            dependencies = with pkgs.python3Packages; [
              fastmcp
              rpyc5
              python-dotenv
              requests
              beautifulsoup4
            ];
          };

          # Run the MCP server.  Invoked as `python -m houdini_mcp` rather than
          # via the `houdini-mcp` console script because only the module reads
          # `MCP_TRANSPORT` (the script calls run_server() with fixed HTTP
          # defaults).  A dedicated python env is used so `houdini_mcp` and its
          # dependencies (fastmcp, rpyc 5.x, …) are all importable.
          #
          #   nix run .#houdini-mcp                          # HTTP on :3055
          #   nix run .#houdini-mcp -- ...                   # extra CLI args
          #   MCP_TRANSPORT=stdio nix run .#houdini-mcp     # stdio, which is
          #                                                   # what opencode uses
          houdiniMcpEnv = pkgs.python3.withPackages (ps: [ houdiniMcp ]);

          houdiniMcpApp = pkgs.writeShellApplication {
            name = "houdini-mcp";
            runtimeInputs = [ pkgs.nix ];
            text = ''
              echo "houdini-mcp: transport=''${MCP_TRANSPORT:-http} port=''${MCP_PORT:-3055}" \
                   "-> Houdini ''${HOUDINI_HOST:-localhost}:''${HOUDINI_PORT:-18811}" >&2
              echo "houdini-mcp: start hrpyc in Houdini's Python Shell first:" >&2
              echo "houdini-mcp:   import hrpyc; hrpyc.start_server(port=18811)" >&2
              exec ${houdiniMcpEnv}/bin/python3 -m houdini_mcp "$@"
            '';
          };
        in
        {
          packages.houdini-mcp = houdiniMcp;

          devShells.default = pkgs.mkShell {
            name = "houdini-project";

            packages = with pkgs; [
              python3 # for out-of-Houdini tooling / linting
              pyright # type-checker; reads ./pyrightconfig.json
              basedpyright # what Zed's Python extension uses; same config
              ruff
            ];

            shellHook = ''
              ${projectEnv}
              ${checkHostHoudini}
              ${linkHouLibs true}
              ${linkHouSite true}
              ${linkTypeStubs}
              ${syncPyrightConfig}
              ${syncOpencodeConfig}
              echo "Houdini project shell"
              echo "  hython:    $(command -v ${hythonBin} || echo 'not found')"
              echo "  Houdini:   ''${HOUDINI_MAJOR_RELEASE:-unknown}"
              echo "  JOB:       $JOB"
              echo "  HIP:       $HIP"
              echo "  hou libs:  $(readlink .hou-libs 2>/dev/null || echo 'unresolved')"
              echo "  hou stubs: $(readlink .stubs 2>/dev/null || echo 'unresolved')"
              echo "  pxr:       $(readlink .hou-site/pxr 2>/dev/null || echo 'unresolved')"
              echo "  python:    $(sed -n 's/.*"pythonVersion": "\([0-9.]*\)".*/\1/p' pyrightconfig.json 2>/dev/null || echo unknown) (Houdini's hython)"
              echo ""
              echo "  houdini      launch the GUI on this project   (nix run .#houdini)"
              echo "  hython       run Python inside Houdini        (nix run .#hython -- script.py)"
              echo "  pyright      type-check with Houdini's hou    (pyright scripts/)"
              echo "  basedpyright type-check as Zed does          (basedpyright scripts/)"
              echo "  ruff         lint                             (ruff check .)"
              echo "  houdini-mcp  MCP server for AI scene control  (nix run .#houdini-mcp)"
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

            # Type-check with `import hou` resolved:
            #   nix run .#pyright
            pyright = pyrightApp;

            # basedpyright (Zed's language server) from the CLI:
            #   nix run .#basedpyright -- scripts/example.py
            basedpyright = basedpyrightApp;

            # Scene control from an AI assistant:
            #   nix run .#houdini-mcp
            # Wired into opencode via .opencode/opencode.json (stdio).
            houdini-mcp = {
              type = "app";
              program = "${houdiniMcpApp}/bin/houdini-mcp";
            };
          };
        };
    };
}
