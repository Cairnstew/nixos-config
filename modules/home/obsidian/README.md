# Obsidian

Note-taking application with vault management, pre-configured vault path, optional git-backed vault cloning, and reproducible community-plugin installation.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable Obsidian |
| `package` | package | `pkgs.obsidian` | Obsidian package |
| `defaultDirectory` | str | `"Documents/Obsidian_Vault"` | Default vault directory |
| `plugins.<id>.enable` | bool | false | Install this plugin into the vault |
| `plugins.<id>.version` | str | — | Release tag to install |
| `plugins.<id>.repo` | str | — | GitHub repo (`owner/name`) publishing the release assets |
| `plugins.<id>.mainJsHash` | str | — | sha256 of `main.js` |
| `plugins.<id>.manifestHash` | str | — | sha256 of `manifest.json` |
| `plugins.<id>.stylesHash` | null/str | null | sha256 of `styles.css` (null if none) |
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

### With a pinned plugin

```nix
my.programs.obsidian.plugins."obsidian-local-rest-api" = {
  enable = true;
  version = "5.5.2";
  repo = "coddingtonbear/obsidian-local-rest-api";
  mainJsHash = "sha256-…";
  manifestHash = "sha256-…";
  stylesHash = "sha256-…";
};
```

Hashes come from the release assets:

```sh
gh release download <version> --repo <owner/name> --dir /tmp/p
for f in main.js manifest.json styles.css; do
  nix store prefetch-file --json "file:///tmp/p/$f" | jq -r .hash
done
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
- Plugins are fetched at build time (pinned by tag + sha256) and copied by activation into `<vault>/.obsidian/plugins/<id>/`, then registered in `community-plugins.json`. Only `main.js`, `manifest.json` and optional `styles.css` are written — the directory stays writable, so plugin state such as `data.json` (where the Local REST API plugin stores its API key) survives switches. Nothing is ever pruned.
- Obsidian must be restarted (or the plugin toggled) to load a newly installed plugin.
- Requires `pkgs.jq` (installed automatically).
