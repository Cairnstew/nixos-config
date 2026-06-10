---
description: Refine and modularize a Python project using class inheritance and clean architecture
agent: build
subtask: true
---

You are a senior Python architect. Your task is to **refine the Python codebase in this project** with a focus on modularisation, clean structure, and idiomatic use of object-oriented design — particularly class inheritance.

## Environment detection

Detect how Python should be invoked in this environment:
!`
# Resolve the Python runner to use for verification steps.
# Priority: uv run (uv2nix / uv-managed devshell) → nix develop → plain python3 fallback.
if command -v uv &>/dev/null && [ -f "pyproject.toml" ] && uv run python --version &>/dev/null 2>&1; then
  echo "PYTHON_RUNNER=uv run python"
  echo "PYTEST_RUNNER=uv run pytest"
  echo "ENV_TYPE=uv2nix/uv-managed"
elif command -v nix &>/dev/null && [ -f "flake.nix" ]; then
  echo "PYTHON_RUNNER=nix develop --command python"
  echo "PYTEST_RUNNER=nix develop --command pytest"
  echo "ENV_TYPE=nix-flake"
elif command -v python3 &>/dev/null; then
  echo "PYTHON_RUNNER=python3"
  echo "PYTEST_RUNNER=python3 -m pytest"
  echo "ENV_TYPE=system-python"
else
  echo "PYTHON_RUNNER=NONE"
  echo "ENV_TYPE=unknown — cannot run Python directly; syntax checks will be skipped"
fi
`

> **Note for NixOS:** Python is not available on `PATH` outside of a managed environment. If `ENV_TYPE` is `uv2nix/uv-managed`, all verification commands below use `uv run`. If `ENV_TYPE` is `nix-flake`, they use `nix develop --command`. If `ENV_TYPE` is `unknown`, skip the execution steps and note them in the summary instead.

## Current project snapshot

Files currently tracked by git:
!`git ls-files --cached --others --exclude-standard | grep -E '\.py$' | head -60`

Recent changes:
!`git log --oneline -5 2>/dev/null || echo "(no git history)"`

Project layout (excludes Nix build artefacts and virtualenvs):
!`find . -name "*.py" \
  ! -path "./.venv/*" \
  ! -path "./result/*" \
  ! -path "./__pycache__/*" \
  ! -path "./.direnv/*" \
  ! -path "./nix/store/*" \
  | sort | head -80`

Existing tooling configuration (linters, formatters, type checkers already declared):
!`cat pyproject.toml 2>/dev/null | grep -A 40 '^\[tool\.' || echo "(no pyproject.toml tool sections found)"`

Existing public API surface (`__all__` declarations):
!`grep -rn '__all__' --include='*.py' . 2>/dev/null || echo "(none found)"`

Project structure documentation (`STRUCTURE.md`):
!`cat STRUCTURE.md 2>/dev/null || echo "(not found)"`

## What to do

Work through the following steps. For each step, only proceed if there is something meaningful to improve — do not make cosmetic changes.

### 1. Structural audit

**Read every `.py` file in full before drawing any conclusions.** Do not audit from filenames alone.

For each file, note:

- Duplicate or near-duplicate logic that could be unified under a shared base class or mixin.
- Groups of free functions operating on the same data or state — candidates for encapsulation.
- Classes that share method signatures or attributes that could be lifted into an `abc.ABC` base.
- Repeated `if isinstance(...)` / `if type(x) ==` dispatch — candidates for polymorphism.
- Large flat modules (>~300 lines) with unrelated concerns — candidates for package split.
- Dead code: unused imports, unreachable branches, private functions never called within the module.
- Missing or inconsistent `__all__` on modules that expose a public API.
- Inconsistent docstring style (mix of Google, NumPy, reStructuredText, or none).
- Import ordering violations (stdlib → third-party → local, each group alphabetically sorted).
- Magic values (bare strings/numbers) that should be named constants or `enum.Enum` members.

Report findings as a structured table: `| File | Issue type | Description | Severity (high/medium/low) |`. Only list files with genuine issues. Then state your **refactor plan** — what you will change, in what order — before touching anything.

### 2. Introduce or refine inheritance hierarchies

Where beneficial:

- Extract a common base class with shared logic; subclasses override only what differs.
- Use `abc.ABC` + `abc.abstractmethod` for contracts that concrete implementations must satisfy.
- Use mixins for orthogonal behaviour (e.g. serialisation, logging, validation) that multiple unrelated classes share — keep mixins single-purpose and stateless where possible.
- Prefer `typing.Protocol` over `abc.ABC` for structural subtyping (duck-typing interfaces, callbacks, adapters) — it avoids forcing inheritance on types you don't own.
- Consider `__slots__` on data-heavy classes where many instances are created — declare in both base and subclass.
- Prefer composition for unrelated behaviour; inheritance only for genuine "is-a" relationships. Do not force a hierarchy.
- Preserve existing public APIs: do not rename methods or change call signatures unless the old form is clearly wrong and nothing outside this project calls it.

### 3. Modularise

- If a module exceeds ~300 lines and contains unrelated concerns, split it into focused sub-modules inside a package.
- Every package `__init__.py` must re-export the public API explicitly via `__all__` so callers never need to know the internal layout.
- Move shared utilities (helpers, type aliases, converters) to a `utils.py` or `common/` sub-package.
- Extract all magic strings and bare numeric constants into a `constants.py` module or, where the values form a closed set, into `enum.Enum` / `enum.IntEnum` / `enum.StrEnum` classes.
- Keep module-level code to an absolute minimum: no side effects at import time other than defining names.
- If `STRUCTURE.md` exists in the project root, read it before making changes and update it afterwards to reflect any structural reorganisations (new packages, renamed modules, split/merged files).

### 4. Type annotations and docstrings

**Type annotations:**

- Add or correct type hints on every class method, free function, and module-level variable you touch. No bare `Any` unless genuinely unavoidable — prefer `object` or a `TypeVar` bound.
- Use `typing.Protocol` for structural interfaces (see step 2).
- Use `typing.overload` where a function has meaningfully different return types depending on argument types.
- Use `typing.Final` for true constants; `typing.ClassVar` for class-level attributes that should not appear on instances.
- Use `TypeVar` with appropriate bounds rather than repeating the same union across multiple signatures.
- Avoid `Optional[X]` — prefer `X | None` (Python 3.10+ style).

**Docstrings:**

- Every public class, method, and free function must have a docstring.
- Pick one style (Google format preferred) and apply it consistently across all touched files.
- One-liner docstrings are fine for trivial methods; use the full Args/Returns/Raises structure for anything non-obvious.
- Do not write docstrings that merely restate the function name ("Returns the value." on `get_value()`) — say something useful or omit.

**Import ordering:**

- Ensure every file groups imports as: stdlib → third-party → local, each group separated by a blank line and sorted alphabetically within the group.
- Remove any unused imports.

### 5. Static analysis (if tools are available)

Run any linters or type checkers already configured in `pyproject.toml`. Do not install new tools.

!`
# Determine runner prefix
if command -v uv &>/dev/null && [ -f "pyproject.toml" ] && uv run python --version &>/dev/null 2>&1; then
  RUN="uv run"
elif command -v nix &>/dev/null && [ -f "flake.nix" ]; then
  RUN="nix develop --command"
else
  RUN=""
fi

# ruff (lint + format check) — most common in modern Python projects
$RUN ruff check . 2>/dev/null && echo "ruff: OK" || echo "ruff: not available or errors found"
$RUN ruff format --check . 2>/dev/null && echo "ruff format: OK" || echo "ruff format: not available or would reformat"

# mypy / pyright — only if configured
if grep -q '\[tool\.mypy\]' pyproject.toml 2>/dev/null; then
  $RUN mypy . 2>/dev/null | tail -5 || echo "mypy: not available"
fi
if grep -q '\[tool\.pyright\]' pyproject.toml 2>/dev/null || [ -f "pyrightconfig.json" ]; then
  $RUN pyright 2>/dev/null | tail -5 || echo "pyright: not available"
fi
`

If ruff reports formatting issues, apply them:
!`
if command -v uv &>/dev/null && [ -f "pyproject.toml" ] && uv run python --version &>/dev/null 2>&1; then
  uv run ruff format . 2>/dev/null && uv run ruff check --fix . 2>/dev/null || true
elif command -v nix &>/dev/null && [ -f "flake.nix" ]; then
  nix develop --command ruff format . 2>/dev/null && nix develop --command ruff check --fix . 2>/dev/null || true
fi
`

Address any mypy/pyright type errors introduced by your changes before proceeding.

### 6. Verify nothing is broken

Use the runner identified in the **Environment detection** block above. Skip execution steps and note them in the summary if `ENV_TYPE` was `unknown`.

Syntax check every touched file:
!`
if command -v uv &>/dev/null && [ -f "pyproject.toml" ] && uv run python --version &>/dev/null 2>&1; then
  PYRUN="uv run python"
elif command -v nix &>/dev/null && [ -f "flake.nix" ]; then
  PYRUN="nix develop --command python"
elif command -v python3 &>/dev/null; then
  PYRUN="python3"
else
  echo "No Python runner available — skipping syntax check"; exit 0
fi
$PYRUN -m py_compile $(git ls-files '*.py') 2>&1 | head -30
`

Run the test suite if one exists:
!`
if command -v uv &>/dev/null && [ -f "pyproject.toml" ] && uv run python --version &>/dev/null 2>&1; then
  uv run pytest --tb=short -q 2>/dev/null || uv run python -m unittest discover -q 2>/dev/null || echo "(no test suite found)"
elif command -v nix &>/dev/null && [ -f "flake.nix" ]; then
  nix develop --command pytest --tb=short -q 2>/dev/null || nix develop --command python -m unittest discover -q 2>/dev/null || echo "(no test suite found)"
elif command -v python3 &>/dev/null; then
  python3 -m pytest --tb=short -q 2>/dev/null || python3 -m unittest discover -q 2>/dev/null || echo "(no test suite found)"
else
  echo "No Python runner available — skipping test run"
fi
`

Fix any errors before moving on.

## Constraints

- Do **not** introduce third-party dependencies that are not already in the project. On a uv2nix setup this is especially important: adding a new `import` without a matching entry in `pyproject.toml` (and a regenerated `uv.lock`) will break the Nix build.
- Do **not** alter CLI entry-points, public module paths, or anything imported by name outside this project. On NixOS these are often referenced by path in `pyproject.toml` `[project.scripts]` or in the Nix package derivation — renaming breaks both.
- Do **not** modify any `.nix` files, `flake.nix`, `flake.lock`, `uv.lock`, or `pyproject.toml` unless the only change needed is adding a missing `[tool.*]` section that is purely cosmetic (e.g. `[tool.pytest.ini_options]`). Packaging changes are out of scope.
- Keep changes atomic: one logical refactor per commit if the project uses git. Commit message format: `refactor(<module>): <what and why>`.
- Prefer `dataclasses.dataclass` or `pydantic.BaseModel` over plain dicts for structured data — only if one of these is already a dependency.
- Remove dead code (unused imports, unreferenced private functions, unreachable branches) — but only if you are certain nothing outside this file calls it. When uncertain, leave it and note it in the summary.
- Do not introduce `enum.Enum` unless the values form a genuinely closed, named set. Do not convert every string constant.
- When in doubt, do less. A codebase with two unnecessary changes is worse than one with zero. Leave well-structured code alone.

## Output

When finished, produce a structured summary:

1. **Audit table** — reproduce the issue table from step 1 with a `Status` column added (`fixed` / `skipped — reason`).
2. **Inheritance changes** — for each new or modified hierarchy: base class, subclasses, what was extracted and why.
3. **Module changes** — files split, packages created, `__all__` additions, constants/enums extracted.
4. **Type annotation coverage** — files touched, any remaining untyped signatures and why.
5. **Static analysis results** — ruff/mypy/pyright output before and after (one line each); any errors left unresolved and why.
6. **Verification** — detected `ENV_TYPE`, whether syntax check and test suite ran, pass/fail.
7. **Left alone** — things you noticed but chose not to change, with a one-line rationale for each.
