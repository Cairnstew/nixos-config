{
  description = "Jupyter notebooks in Zed with a uv-managed Python environment";

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
        {
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              # Fallback interpreter and what `uv` looks at first. The venv's
              # own interpreter is uv's managed CPython, pinned by
              # .python-version — NOT this store path. A venv built from the
              # store python breaks the moment that path is garbage-collected,
              # whereas uv's download survives `nix gc`.
              python312
              uv
              # Lint/type tools come from nixpkgs rather than the venv, so they
              # are runnable binaries even before `uv sync` has ever run. The
              # PyPI wheels of ruff/basedpyright are dynamically linked against
              # paths NixOS does not have and fail to start.
              ruff
              basedpyright
              git
              # The editor itself, so `nix develop` followed by `zeditor .` works
              # on a host where Zed is not installed system-wide. Drop this line
              # if `my.programs.zed-editor` already provides it.
              zed-editor
            ];

            # This is the reason the shell exports a library path at all. `uv`
            # installs PyPI wheels for numpy/pandas/matplotlib, which link
            # against libz.so.1, libstdc++.so.6 and friends *by soname*. NixOS
            # has no /lib, so without this the kernel dies at the first
            # `import pandas` with "libz.so.1: cannot open shared object file"
            # — an error that looks like a broken notebook, not a missing lib.
            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
              pkgs.zlib
              pkgs.stdenv.cc.cc.lib
            ];

            shellHook = ''
              # Keep uv's cache inside the project rather than leaking a
              # multi-hundred-MB wheel cache into $HOME.
              export UV_CACHE_DIR="$PWD/.uv-cache"
              export PYTHONDONTWRITEBYTECODE=1

              if [ ! -x .venv/bin/python ]; then
                echo "jupyter-zed: creating .venv (first run only, needs network)…"
                uv sync --quiet || echo "jupyter-zed: uv sync failed — fix pyproject.toml and re-enter the shell"
              fi

              if [ -x .venv/bin/python ]; then
                # Register the kernelspec Zed looks for. The script is
                # idempotent and derives the kernel name from [project].name in
                # pyproject.toml, so re-running it on every shell entry keeps
                # the spec pointing at the current .venv even after
                # `uv sync` has rebuilt it. `|| true`: a failed kernelspec
                # install must not break the shell.
                .venv/bin/python "$PWD/tools/install_kernel.py" >/dev/null || true

                # Put the venv first so `python`, `jupyter`, `pytest` and `ruff`
                # are the project's own, not the interpreter-only Nix python.
                export PATH="$PWD/.venv/bin:$PATH"
              fi

              echo "jupyter-zed dev shell — python $(python -V 2>&1 | cut -d' ' -f2), uv $(uv --version 2>/dev/null | cut -d' ' -f2)"
              echo "  zeditor .                 # open this project in Zed"
              echo "  jupyter lab               # browser UI, same kernelspec"
              echo "  jupyter kernelspec list   # what Zed can see"
              echo "  ruff check src/           # lint (nixpkgs ruff, not the wheel)"
            '';
          };

          # `nixfmt-rfc-style` is now an alias for `pkgs.nixfmt`; the alias
          # emits a deprecation warning on every use.
          formatter = pkgs.nixfmt;
        };
    };
}
