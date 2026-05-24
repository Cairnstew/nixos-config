# Obsidian

Note-taking application with vault management, pre-configured vault path, and optional git-backed vault cloning.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable Obsidian |
| `package` | package | `pkgs.obsidian` | Obsidian package |
| `defaultDirectory` | str | `"Documents/Obsidian_Vault"` | Default vault directory |
| `repo.enable` | bool | false | Clone vault from git repo |
| `repo.url` | str | `""` | GitHub repo URL |
| `repo.tokenFile` | null/str | null | Path to GitHub token file |

## Usage

```nix
my.programs.obsidian = {
  enable = true;
  defaultDirectory = "Notes/MainVault";
};
```

### With git-backed vault

```nix
my.programs.obsidian = {
  enable = true;
  repo = {
    enable = true;
    url = "https://github.com/user/vault";
    tokenFile = config.age.secrets.github-token.path;
  };
};
```

## Notes

- Generates `~/.config/obsidian/obsidian.json` with the vault pre-registered.
- When `repo.enable` is true and `tokenFile` is provided, the activation script will clone the vault on first setup and configure git credential storage.
- Requires `pkgs.jq` (installed automatically).
