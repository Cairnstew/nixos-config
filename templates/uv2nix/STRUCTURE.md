# Project Structure

```
.
├── .github/                     # CI/CD & dependency management
│   ├── actions/
│   │   └── setup-nix/
│   │       └── action.yml       #   Reusable: Nix installer + cache + uv
│   ├── workflows/
│   │   ├── ci.yml               #   Orchestrator — path detection, fan-out
│   │   ├── lint.yml             #   Reusable — ruff (format + lint)
│   │   ├── typecheck.yml        #   Reusable — mypy
│   │   ├── test-unit.yml        #   Reusable — pytest unit + coverage
│   │   ├── test-integration.yml #   Reusable — pytest integration (soft-fail)
│   │   ├── nix.yml              #   Reusable — flake check + build
│   │   ├── audit.yml            #   Reusable — pip-audit + bandit
│   │   ├── vm-test.yml          #   Reusable — NixOS VM tests
│   │   ├── release.yml          #   Tag v* — Nix build, PyPI OIDC, GH release
│   │   └── update-flake-lock.yml #  Weekly — automated flake.lock bump
│   └── renovate.json            #   Renovate config — batching Python & Nix dep PRs
│
├── flake.nix                 # Nix flake — thin orchestrator, delegates to nix/
├── flake.lock                # Nix lock file — pins all flake input versions
├── pyproject.toml            # Python project metadata & dependency declarations
├── uv.lock                   # uv lock file — exact dependency resolution, drives uv2nix overlay
├── .pre-commit-config.yaml   # Pre-commit hooks (ruff, mypy, nixpkgs-fmt)
├── Justfile                  # Developer command shortcuts
├── .python-version           # Python version pin (3.12)
│
├── nix/                      # Nix building blocks
│   ├── default.nix           #   Package derivation (mkApplication)
│   ├── module.nix            #   NixOS module — activation script + systemd service
│   ├── home-module.nix       #   Home Manager module — user env package
│   └── vm-tests.nix          #   NixOS VM integration tests
│
├── src/
│   ├── uv2nix_template/          # Application package
│   │   ├── __init__.py           #   Public API + version
│   │   ├── __main__.py           #   python -m uv2nix_template
│   │   ├── py.typed              #   PEP 561 marker
│   │   ├── exceptions.py         #   Uv2nixError hierarchy
│   │   ├── models/
│   │   │   ├── __init__.py
│   │   │   └── config.py         #   AppConfig, BaseResult, SuccessResult, ErrorResult
│   │   ├── services/
│   │   │   ├── __init__.py
│   │   │   ├── base.py           #   BaseService
│   │   │   ├── config.py         #   ConfigService
│   │   │   ├── generator.py      #   GeneratorService
│   │   │   └── validator.py      #   ValidatorService
│   │   ├── cli/
│   │   │   ├── __init__.py
│   │   │   ├── main.py           #   Typer app + callback
│   │   │   ├── context.py        #   AppContext dataclass
│   │   │   └── commands/
│   │   │       ├── __init__.py
│   │   │       ├── base.py       #   BaseCommand
│   │   │       ├── init.py       #   InitCommand
│   │   │       ├── generate.py   #   GenerateCommand
│   │   │       └── validate.py   #   ValidateCommand
│   │   └── textual_ui/           #   TUI package (Textual)
│   │       ├── __init__.py
│   │       ├── app.py            #   UvTemplateApp
│   │       ├── base.py           #   BaseScreen, ListScreen, DetailScreen
│   │       ├── actions.py        #   Mixins: LoggingMixin, RefreshMixin, SelectionMixin, NavigationMixin
│   │       ├── screens/
│   │       │   ├── __init__.py
│   │       │   ├── main.py       #   MainScreen
│   │       │   ├── search.py     #   SearchScreen
│   │       │   └── detail.py     #   ItemDetailScreen
│   │       └── styles/
│   │           ├── base.tcss
│   │           └── main.tcss
│   │
│   └── textual_ui/               # Legacy alias — kept for backwards compat
│       └── app.py                #   Old TextualApp (redirects to uv2nix_template.textual_ui)
│
├── tests/
│   ├── conftest.py               #   Root: CliRunner, shared fixtures
│   ├── unit/                     #   Fast, no I/O — mocks & fakes only
│   │   ├── conftest.py
│   │   ├── test_models.py
│   │   ├── test_services.py
│   │   ├── test_commands.py
│   │   ├── test_cli.py
│   │   ├── test_tui_base.py
│   │   └── test_context.py
│   ├── integration/              #   CLI subprocess invocation
│   │   ├── conftest.py
│   │   └── test_cli_invocation.py
│   ├── nix_eval/                 #   Nix eval tests (require nix in PATH)
│   │   ├── conftest.py
│   │   └── test_module_eval.py
│   └── nixos/                    #   NixOS VM test fixtures
│       └── basic.nix
│
├── docs/
│   ├── reference/
│   │   ├── cli.md                #   CLI command reference
│   │   ├── module.md             #   NixOS module option reference
│   │   └── ci.md                 #   CI workflow reference
│   └── guides/
│       ├── quickstart.md         #   Getting started guide
│       └── nixos-integration.md  #   NixOS integration guide
│
├── UV2NIX.md                 # uv2nix reference & lookup table
├── AGENTS.md                 # Instructions for AI coding agents
├── GOTCHAS.md                # Common pitfalls
├── HEATMAP.md                # Complexity/fragility heatmap
├── STRUCTURE.md              # This file
├── README.md                 # Project readme
├── CHANGELOG.md              # Release changelog
├── CONTRIBUTING.md           # Contribution guide
├── RELEASE.md                # Release process
├── TESTS.md                  # Test tier layout and conventions
│
├── .envrc                    # direnv: use flake
├── .gitignore                # Git ignore rules
└── uv.lock.example           # Example lock file for bootstrapping
```

## Class Hierarchy

```
# ── Core domain models (src/uv2nix_template/models/) ─────────────────────────

BaseModel (pydantic.BaseModel)
  └── AppConfig                  # serialised to /etc/uv2nix-template/config.json
        └── (no further subclasses — leaf)

BaseResult (pydantic.BaseModel)  # wraps any operation outcome
  ├── SuccessResult
  └── ErrorResult

# ── CLI context (src/uv2nix_template/cli/) ───────────────────────────────────

AppContext (dataclass)           # passed via typer.Context.obj
  # fields: verbose, config_path, config (AppConfig)

# ── CLI commands (src/uv2nix_template/cli/commands/) ─────────────────────────

BaseCommand                      # NOT a Typer class — plain Python
  ├── method: run() -> BaseResult               # subclass hook: override to implement
  ├── method: handle_result(r: BaseResult) -> None  # shared output logic
  └── method: abort(msg: str) -> None               # shared error+exit logic
      ├── InitCommand(BaseCommand)
      ├── GenerateCommand(BaseCommand)
      └── ValidateCommand(BaseCommand)

# ── Textual TUI (src/uv2nix_template/textual_ui/) ────────────────────────────

# --- Mixins (actions.py) ---
LoggingMixin                     # adds self.log_event(msg)
RefreshMixin                     # adds action_refresh()
SelectionMixin                   # adds action_select() + selected property
NavigationMixin                  # adds action_back(), action_forward()

# --- Base screen (base.py) ---
BaseScreen(Screen, LoggingMixin)
  # CSS_PATH = styles/base.tcss
  # BINDINGS: q=quit, ?=help
  # compose(): Header → compose_content() → Footer
  # compose_content(): subclass hook (yields nothing by default)
  ├── ListScreen(BaseScreen, RefreshMixin, SelectionMixin)
  │     # compose_content(): yields DataTable
  │     # subclass hook: load_rows() -> list[tuple]
  │     ├── MainScreen(ListScreen)          # screens/main.py
  │     └── SearchScreen(ListScreen)        # screens/search.py
  └── DetailScreen(BaseScreen, NavigationMixin)
        # compose_content(): yields Static + ScrollView
        # subclass hook: load_detail(key: str) -> str
        └── ItemDetailScreen(DetailScreen)  # screens/detail.py

# --- App (app.py) ---
UvTemplateApp(App)
  # SCREENS: {"main": MainScreen, "detail": ItemDetailScreen, "search": SearchScreen}
  # on_mount(): push_screen("main")

# ── Services (src/uv2nix_template/services/) ─────────────────────────────────

BaseService                      # sets up logger, holds AppConfig ref
  ├── ConfigService(BaseService)
  ├── GeneratorService(BaseService)
  └── ValidatorService(BaseService)

# ── Exceptions (src/uv2nix_template/exceptions.py) ───────────────────────────

Uv2nixError(Exception)           # project root exception
  ├── ConfigError(Uv2nixError)
  ├── GenerationError(Uv2nixError)
  └── ValidationError(Uv2nixError)
```

## Architecture

```
pyproject.toml  ──uv add/lock──►  uv.lock
                                      │
                                      ▼
flake.nix  ──workspace.mkPyprojectOverlay──►  Nix overlay
  │                                                  │
  │  pyproject-build-systems.overlays.wheel ─────────┤
  │                                                  │
  └── composeManyExtensions ─────────────────────────► pythonSet
                                                           │
                                               ┌───────────┼───────────────────┐
                                               ▼           ▼                   ▼
                                    nix/default.nix   nix/devshell.nix    nix/module.nix
                                    (mkApplication)   (mkShell)           (systemd service)
```

## Key concepts

- **workspace** — uv2nix treats every project as a workspace (even single-project ones).
  `loadWorkspace` discovers & parses all members.
- **overlay** — generated from `uv.lock` via `mkPyprojectOverlay`. Adds every dependency
  as a Nix package attribute.
- **editableOverlay** — variant for development: installs your local package as editable
  (source-linked) so changes take effect immediately.
- **pythonSet** — Nixpkgs Python package set extended with the uv2nix overlays.
- **virtualenv** — aggregate derivation that combines all selected packages into a single
  environment (via `mkVirtualEnv`).
- **mkApplication** — wraps a venv into a standalone Nix package, hiding Python internals.

## Nix Flake outputs

| Output | Source file | Description |
|--------|-------------|-------------|
| `packages.default` | `nix/default.nix` | Production build via `mkApplication` |
| `devShells.default` | `flake.nix` (inline) | Full dev environment with editable installs |
| `devShells.bootstrap` | `flake.nix` (inline) | Python + uv only (no uv2nix dependency) |
| `apps.default` | `flake.nix` | `nix run .` support |
| `overlays.default` | `flake.nix` (inline) | Adds `uv2nix-template` to `pkgs` |
| `nixosModules.default` | `nix/module.nix` | NixOS module with activation script |
| `homeManagerModules.default` | `nix/home-module.nix` | User environment package |
| `checks` | `flake.nix` (inline) | build, venv, format, app-help checks |
| `vmTests` | `nix/vm-tests.nix` | NixOS VM integration tests |
