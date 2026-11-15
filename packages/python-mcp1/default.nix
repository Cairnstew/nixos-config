# =============================================================================
# python-mcp1 — Model Context Protocol Python SDK, 1.x line
# =============================================================================
# Why this exists: nixpkgs moved `python3Packages.mcp` to the 2.x SDK, which
# renamed/split its modules (`mcp-types`, `httpx2`, ...). `fastmcp` 3.x (and
# therefore every server built on it, including diagrams-mcp) requires
# `mcp>=1.24,<2`, and nixpkgs marks `fastmcp`/`fastmcp-slim` broken for exactly
# that reason. This packages the last 1.x release so a Python environment can
# pin `mcp` back and get a working `fastmcp` — see packages/diagrams-mcp.
#
# Built from the PyPI wheel: upstream derives its version from git via
# `uv-dynamic-versioning`, so a source build without `.git` loses it.
# =============================================================================
{ lib
, buildPythonPackage
, fetchurl
, anyio
, cryptography
, httpx
, httpx-sse
, jsonschema
, pydantic
, pydantic-settings
, pyjwt
, python-multipart
, sse-starlette
, starlette
, typing-extensions
, typing-inspection
, uvicorn
}:

buildPythonPackage rec {
  pname = "mcp";
  version = "1.30.0";
  format = "wheel";

  # Exact PyPI URL: the Python SDK ships wheels under a hash-partitioned path
  # that fetchPypi's legacy `packages/source/...` layout does not cover.
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/f5/f4/e58bc33317c92a0203664daaf00bf6f41166cc0149e5d6870a03f7cd004a/mcp-1.30.0-py3-none-any.whl";
    hash = "sha256-Zm7bUAlQPhBHydYDRqdW+UsmHwXMJiXyPUHHKP/EhNA=";
  };

  dependencies = [
    anyio
    # `pyjwt[crypto]` upstream: the crypto extra is just a hard dependency here.
    cryptography
    httpx
    httpx-sse
    jsonschema
    pydantic
    pydantic-settings
    python-multipart
    pyjwt
    sse-starlette
    starlette
    typing-extensions
    typing-inspection
    uvicorn
  ];

  # The wheel ships no tests; upstream's suite lives in its git repo.
  doCheck = false;

  # `starlette>=0.48` is only required on 3.14+; nixpkgs' starlette satisfies it.
  meta = {
    description = "Model Context Protocol SDK (1.x line, for fastmcp 3.x)";
    homepage = "https://modelcontextprotocol.io";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
