# Python Project with uv2nix

A modern Python project template using:
- **[uv](https://docs.astral.sh/uv/)** — Fast Python package installer and resolver
- **[uv2nix](https://github.com/pyproject-nix/uv2nix)** — Nix integration for uv projects
- **[flake-parts](https://flake.parts/)** — Modular Nix flakes

## Quick Start

### 1. Bootstrap the project

```bash
# Enter bootstrap shell to generate pyproject.toml
nix develop .#bootstrap

# Sync dependencies (this creates uv.lock)
uv sync

# Exit and enter full development shell
exit
nix develop
```

### 2. Development workflow

```bash
# Run your application
python -m my_project

# Run tests
pytest

# Add dependencies
uv add <package>

# Add dev dependencies
uv add --dev <package>

# Update lock file
uv lock
```

### 3. Building and running

```bash
# Build the package
nix build

# Run the application
nix run

# Run tests
nix flake check
```

## Project Structure

```
.
├── flake.nix              # Nix flake configuration
├── modules/
│   ├── flake.nix          # Main module (config, shells, apps)
│   ├── python-env.nix     # Python environment setup
│   └── pyproject.nix      # pyproject.toml generator
├── src/
│   └── my_project/        # Your Python package
│       ├── __init__.py
│       └── __main__.py
├── tests/                 # Test files
└── README.md
```

## Customization

### Change project name

Edit `modules/flake.nix` and update:

```nix
config.project = {
  name = "your-project-name";
  version = "0.1.0";
  description = "Your project description";
  # ...
};
```

Then regenerate `pyproject.toml`:

```bash
nix run .#sync-pyproject
```

### Add dependencies

Use `uv add` for runtime dependencies:

```bash
uv add requests pydantic
```

Use `uv add --dev` for development dependencies:

```bash
uv add --dev pytest ruff mypy
```

### Configure entry points

Add CLI scripts in `modules/flake.nix`:

```nix
config.project.scripts = {
  my-cli = "my_project.cli:main";
};
```

### Build system overrides

If packages fail to build due to missing build dependencies, add overrides:

```nix
config.uv2nix.buildSystemOverrides = {
  some-package = { setuptools = [ ]; cython = [ ]; };
};
```

## direnv (optional)

If you have [direnv](https://direnv.net/) installed:

```bash
direnv allow
```

This will automatically enter the development shell when you `cd` into the project.

## License

[Your license here]
