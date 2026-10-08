# Houdini Project Template

A Houdini project scaffold whose flake provides a development shell and
run-apps wired to the **Houdini already installed on your system**.

## Why the system Houdini

SideFX Houdini is proprietary: it cannot be fetched by Nix and is not in
nixpkgs. This template therefore does **not** depend on a `houdini` package.
It uses the `houdini`/`hython` wrappers that nixos-config's
`my.programs.houdini` module installs into `/run/current-system/sw/bin`
(a `houdini-nix` build plus the FHS launcher, Vulkan/Qt/QML fix-ups, and the
licensing setup).

`nix develop` and `nix run` inherit the ambient `PATH`, so the system wrappers
are found by name — and they must be used by name. Never add `$HFS/bin` to
`PATH`: that bypasses the module's launcher and Houdini crashes on startup.

## Requirements

- Houdini installed system-wide:

  ```nix
  my.programs.houdini.enable = true;
  ```

- A valid SideFX license (Apprentice/NC or full), configured by the module.
- `nix` with flakes enabled (or `direnv`).

## Usage

```bash
# Optionally scaffold a fresh project from the nixos-config flake:
nix flake init -t ~/nixos-config#houdini

# Enter the dev shell (direnv: `direnv allow` once):
nix develop

# Inside the shell, `hython` and `houdini` come from the system, and the
# project environment below is already active.
hython scripts/example.py
houdini hip/                                    # open the GUI here
```

Without entering a shell:

```bash
nix run .#houdini            # launch the GUI with the project environment
nix run .#hython -- scripts/example.py
```

## Project environment

On shell entry the flake exports:

| Variable | Value | Purpose |
|----------|-------|---------|
| `JOB` | project root | Houdini's `$JOB` project directory |
| `HIP` | `<project>/hip` | directory Houdini opens `.hip` files from |
| `HOUDINI_PATH` | `<project>/houdini:&` | loads `./houdini` as a Houdini package |

`&` expands to Houdini's default search path, so `./houdini` is *prepended*
rather than replacing the built-in paths.

## Layout

```
.
├── flake.nix          # dev shell + `nix run` apps (system Houdini)
├── hip/               # scene files ($HIP) — *.hip, *.hiplc
├── houdini/           # a Houdini package, auto-loaded via HOUDINI_PATH
│   ├── otls/          #   digital assets (*.hda, *.otl)
│   ├── python/        #   startup/module Python (importable as `houdini.*`)
│   ├── scripts/       #   shelf/startup scripts (123.py, 456.py, ...)
│   ├── vex/           #   VEX includes (.vfl), included from wrangles
│   └── toolbar/       #   shelf definitions (.shelf)
└── scripts/           # standalone hython tools (run with `nix run .#hython`)
```

## Notes

- The template's `flake.lock` pins nixpkgs + flake-parts. Bump with
  `nix flake update`.
- Nothing in this project vendors Houdini; it stays a thin wrapper over the
  system install, so the project keeps working across Houdini upgrades.
