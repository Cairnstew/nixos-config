# =============================================================================
# diagrams-mcp — MCP server for cloud architecture / Mermaid / PlantUML diagrams
# =============================================================================
# Upstream: https://github.com/ByteOverDev/diagrams-mcp (PyPI: diagrams-mcp-server)
# Renders three kinds of diagrams and returns them as inline images over stdio:
#   - render_diagram  → mingrammer/diagrams (needs Graphviz `dot`)
#   - render_mermaid  → Mermaid CLI (`mmdc`, needs Chromium)
#   - render_plantuml → PlantUML jar (needs a JRE)
#
# Packaging notes:
#   - Neither `diagrams-mcp-server` nor `pyseccomp` is in nixpkgs, so pyseccomp
#     (a pure-Python ctypes/libseccomp wrapper used by the render sandbox as the
#     network-blocking backstop) is packaged here too.
#   - nixpkgs' `fastmcp` is currently marked broken because `python3Packages.mcp`
#     moved to the 2.x SDK while fastmcp 3.x requires `mcp>=1.24,<2`. The Python
#     environment below pins `mcp` back to the 1.x line (packages/python-mcp1),
#     which un-breaks fastmcp.
#   - Upstream pins `fastmcp==3.2.3`; the environment ships 3.4.7, which still
#     provides every API this server uses (FastMCP, .mount,
#     RateLimitingMiddleware, fastmcp.utilities.types.{Image,File}), so the pin
#     is relaxed.
#   - Upstream's `main()` calls `mcp.run(stateless_http=True)`. That keyword is
#     only valid for the HTTP transports — with FastMCP's default stdio
#     transport it raises `TypeError: run_stdio_async() got an unexpected
#     keyword argument 'stateless_http'`, i.e. the published entry point cannot
#     start on stdio at all (upstream runs it as a container behind
#     FASTMCP_TRANSPORT=http). MCP clients here speak stdio, so postPatch pins
#     the transport explicitly.
#   - The render sandbox re-launches rendering code as `sys.executable -I`, and
#     `-I` drops PYTHONPATH. A plain `buildPythonApplication` script therefore
#     cannot import `diagrams`/`pyseccomp` (it only gets them via PYTHONPATH),
#     so the server is run from a `python.withPackages` environment instead —
#     the dependencies then live in the interpreter's own site-packages.
# =============================================================================
{ lib
, python3
, fetchurl
, runCommand
, libseccomp
, graphviz
, plantuml
, jre
, mermaid-cli
, makeWrapper
}:

let
  # Pin `mcp` back to 1.x so `fastmcp` stops being broken; see the header note.
  python = python3.override {
    packageOverrides = new: old: {
      mcp = new.callPackage ../python-mcp1 { };
      # nixpkgs runs the upstream suites from installCheckPhase; they encode
      # mcp 2.x-era expectations and are irrelevant to a runtime version pin.
      fastmcp-slim = old.fastmcp-slim.overrideAttrs (prev: {
        doCheck = false;
        doInstallCheck = false;
        meta = prev.meta // { broken = false; };
      });
      fastmcp = old.fastmcp.overrideAttrs (prev: {
        doCheck = false;
        doInstallCheck = false;
        meta = prev.meta // { broken = false; };
      });
    };
  };

  pyseccomp = python.pkgs.buildPythonPackage rec {
    pname = "pyseccomp";
    version = "0.1.2";
    pyproject = true;

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/08/e2/f761ad7bd34745af8c8aa6d76a71a240eef45ee4635e2022dcc1b133b4d8/pyseccomp-0.1.2.tar.gz";
      hash = "sha256-DVTvrPcb2kvf0hIz9URLcwy+z1k9YC95bmQSqGgiWL0=";
    };

    build-system = [ python.pkgs.setuptools ];

    # The render sandbox re-execs rendering code with ONLY `PATH` in the
    # environment, so `ctypes.util.find_library("seccomp")` (which shells out to
    # ldconfig) cannot resolve libseccomp there. Bake the absolute soname in.
    postPatch = ''
      substituteInPlace pyseccomp.py \
        --replace-fail 'ctypes.util.find_library("seccomp")' '"${lib.getLib libseccomp}/lib/libseccomp.so.2"'
    '';

    # Upstream has no test suite beyond a manual README walkthrough.
    doCheck = false;

    meta = {
      description = "An interface to libseccomp using ctypes, API compatible with libseccomp's Python bindings";
      homepage = "https://github.com/adiSuper94/pyseccomp";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  };

  # `buildPythonPackage` (not buildPythonApplication) so the package carries
  # `pythonModule` and is therefore pulled into `python.withPackages` below.
  server = python.pkgs.buildPythonPackage rec {
    pname = "diagrams-mcp-server";
    version = "0.3.0";
    pyproject = true;

    # Exact PyPI URL (fetchPypi's legacy `packages/source/...` mirror path 404s
    # for this package).
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/d0/20/83f92b66d7ce25c06c834eae2be855b07ff69aa16bd59c4b222afd5b0087/diagrams_mcp_server-0.3.0.tar.gz";
      hash = "sha256-sANmIO6gGJJXRXrH0pWHmHP4TmOLik1gSNF/PUAHYRs=";
    };

    postPatch = ''
      # The published entry point cannot start on stdio (see the header note).
      substituteInPlace src/diagrams_mcp/server.py \
        --replace-fail 'mcp.run(stateless_http=True)' 'mcp.run(transport="stdio")'

      # The landlock ruleset only grants reads beneath the sys.path entries
      # themselves. On NixOS every `python.withPackages` site-packages entry is a
      # symlink into the immutable store, and the resolved target sits outside
      # every rule -- so `import diagrams.aws` fails with a misleading
      # `ModuleNotFoundError`. Allow read-only access to the store.
      substituteInPlace src/diagrams_mcp/sandbox.py \
        --replace-fail '_add_path_rule(_sys.prefix, ro_rights)' '[ _add_path_rule(p, ro_rights) for p in ("/nix/store", _sys.prefix) ]'
    '';

    build-system = [ python.pkgs.hatchling ];

    dependencies = with python.pkgs; [
      diagrams
      fastmcp
      pyseccomp
    ];

    nativeBuildInputs = [ python.pkgs.pythonRelaxDepsHook ];

    # Upstream pins fastmcp==3.2.3 exactly; see the header note.
    pythonRelaxDeps = [ "fastmcp" ];

    # Upstream has no offline test suite (tests drive the MCP client end to end).
    doCheck = false;

    meta = {
      description = "MCP server for rendering architecture diagrams using mingrammer/diagrams, Mermaid, and PlantUML";
      homepage = "https://github.com/ByteOverDev/diagrams-mcp";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
      mainProgram = "diagrams-mcp-server";
      maintainers = [ "seanc" ];
    };
  };

  # Interpreter whose site-packages holds the server and its runtime deps, so
  # the sandbox's `python -I` subprocesses can import them.
  pythonEnv = python.withPackages (_: [
    server
    python.pkgs.diagrams
    python.pkgs.fastmcp
    pyseccomp
  ]);
in
runCommand "diagrams-mcp-server-${server.version}"
{
  nativeBuildInputs = [ makeWrapper ];
  meta = server.meta;
} ''
  mkdir -p $out/bin
  # Every renderer shells out through the sandbox with only `PATH` forwarded, so
  # the external engines have to be reachable there. PLANTUML_JAR is read at
  # import time from os.environ (upstream default is the Docker-only
  # /opt/plantuml.jar).
  makeWrapper ${lib.getExe' pythonEnv "diagrams-mcp-server"} $out/bin/diagrams-mcp-server \
    --prefix PATH : ${lib.makeBinPath [ graphviz plantuml jre mermaid-cli ]} \
    --set PLANTUML_JAR ${plantuml}/lib/plantuml.jar \
    --set DIAGRAMS_INLINE_DEFAULT 1
''
