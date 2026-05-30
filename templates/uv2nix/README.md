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
├── .envrc                 # direnv integration
├── .gitignore
├── AGENTS.md              # AI agent guidance
├── GOTCHAS.md             # Common pitfalls
├── HEATMAP.md             # Codebase hot spots
├── STRUCTURE.md           # Detailed structure
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

### Add optional dependencies

Declare optional dependency groups in `modules/flake.nix`:

```nix
config.project.optionalDependencies = {
  web = [ "fastapi" "uvicorn" ];
  db = [ "sqlalchemy" "asyncpg" ];
};
```

Install them with:

```bash
uv add --optional web fastapi uvicorn
```

### Configure entry points

Add CLI scripts in `modules/flake.nix`:

```nix
config.project.scripts = {
  my-cli = "my_project.cli:main";
};
```

### Add system packages to dev shell

Some projects need system-level tools in the dev shell (e.g., PostgreSQL client, Docker). Configure via `extraDevPackages`:

```nix
config.project.extraDevPackages = pkgs: [ pkgs.postgresql pkgs.docker-compose ];
```

### Set environment variables

Configure shell environment variables in `modules/flake.nix`:

```nix
config.project.shellEnv = {
  DATABASE_URL = "postgresql://user:pass@localhost:5432/mydb";
};
```

For secrets, use a `.env` file (see below) instead of hardcoding values.

### Customize shell hints

The hints shown when entering the dev shell are configurable:

```nix
config.project.shellHints = [
  "my-cli --help        # see available commands"
  "pytest               # run tests"
  "docker compose up    # start services"
];
```

### Build system overrides

If packages fail to build due to missing build dependencies, add overrides:

```nix
config.uv2nix.buildSystemOverrides = {
  some-package = { setuptools = [ ]; cython = [ ]; };
};
```

## Environment files (`.env`)

The template supports `.env` files for local configuration (API keys, database URLs, etc.):

1. Copy `.env.example` to `.env` (if provided by your project).
2. The `.envrc` file loads it automatically via `direnv`:
   ```bash
   [ -f .env ] && dotenv .env
   ```
3. The `.env` file is in `.gitignore` — secrets stay local.

**Note:** `dotenv` only loads variables when using direnv. For `nix develop` without direnv, the `.env` is not loaded unless you add sourcing logic to `shellHook`.

## Custom hatch build targets

If your package source is not under `src/<project_name>/` (e.g., flat layout), update `modules/pyproject.nix`:

```nix
tool.hatch.build.targets.wheel = {
  packages = [ "." ];  # or ["src/my_pkg"] for custom layout
};
```

By default, the template uses `[ "src/${cfg.name}" ]` to match the `src/<name>/` directory.

## direnv (optional)

If you have [direnv](https://direnv.net/) installed:

```bash
direnv allow
```

This will automatically enter the development shell when you `cd` into the project.

## License

[Your license here]
