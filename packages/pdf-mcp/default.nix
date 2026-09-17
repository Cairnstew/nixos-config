{ lib
, stdenv
, python3
, fetchFromGitHub
, makeWrapper
, tesseract
}:

stdenv.mkDerivation rec {
  pname = "pdf-mcp";
  version = "3.2.0";

  src = fetchFromGitHub {
    owner = "jztan";
    repo = "pdf-mcp";
    rev = "31893b974730100b4588b6834d14a6be8717edf4";
    hash = "sha256-DDAlBxl31UJ84TYLmVdLvCIS3ezeN6aDu/WaMtFaSCo=";
  };

  nativeBuildInputs = [ makeWrapper python3 ];

  buildPhase = ''
        runHook preBuild
        # Create a wrapper script that installs and runs pdf-mcp
        mkdir -p $out/bin
        cat > $out/bin/pdf-mcp << WRAPPER
    #!/bin/sh
    set -e

    # Create a user-writable directory for the virtual environment
    VENV_DIR="\$HOME/.local/share/pdf-mcp/venv"

    # Create virtual environment if it doesn't exist
    if [ ! -d "\$VENV_DIR" ]; then
        echo "Setting up pdf-mcp environment..."
        mkdir -p "\$(dirname "\$VENV_DIR")"
        ${python3}/bin/python3 -m venv "\$VENV_DIR"
        "\$VENV_DIR/bin/pip" install --upgrade pip
        "\$VENV_DIR/bin/pip" install pdf-mcp
    fi

    # Run pdf-mcp from the virtual environment
    exec "\$VENV_DIR/bin/pdf-mcp" "\$@"
    WRAPPER
        chmod +x $out/bin/pdf-mcp
        runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    runHook postInstall
  '';

  meta = with lib; {
    description = "MCP server for agentic RAG over PDFs with hybrid search, selective page reads, tables, images, OCR, and chart data";
    homepage = "https://github.com/jztan/pdf-mcp";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "pdf-mcp";
    maintainers = [ "seanc" ];
  };
}
