# GitHub CLI (gh)

Configures the GitHub CLI tool with optional token injection via agenix.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.gh.enable` | `false` | Enable gh CLI |
| `my.programs.gh.package` | `pkgs.gh` | gh package |
| `my.programs.gh.tokenFile` | auto (from secrets) | Path to file containing GitHub PAT |
| `my.programs.gh.extensions` | `[]` | gh extensions to install |
| `my.programs.gh.settings` | `{}` | gh config.yml settings |
| `my.programs.gh.hosts` | `{}` | Host config entries |

## Usage

```nix
my.programs.gh.enable = true;
```

The `tokenFile` is auto-detected from the secrets catalog
(`config.age.secrets.github-token.path`) when the `secrets/github/token.age`
file exists and is wired via `modules/nixos/secrets`. You can override it:

```nix
my.programs.gh.tokenFile = "/path/to/my/token";
```

## Token Export

When `tokenFile` is set, two things happen:
1. `GITHUB_TOKEN` is exported at shell startup (zsh + bash) — sufficient for
   `gh` commands, `github-actions-cleanup`, and other GitHub tools
2. `gh auth login --with-token` runs during activation — so `gh auth status`
   shows "Logged in". This requires the PAT to have **`repo` + `read:org` + `gist`** scopes.

If your PAT lacks `read:org`, `gh auth login` will fail (logged at activation
time), but `GITHUB_TOKEN` export still works for all CLI operations.
