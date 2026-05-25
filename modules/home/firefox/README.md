# Firefox

Firefox browser configuration with bookmark and extension support.

Extensions are installed declaratively via Firefox Enterprise Policies
(`ExtensionSettings`). Firefox downloads and manages them itself, so no
manual XPI fetching or hash pinning is required.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.firefox.enable` | `false` | Enable Firefox |
| `my.programs.firefox.package` | `pkgs.firefox` | Firefox package |
| `my.programs.firefox.extensions` | `["ublock-origin" "1password"]` | Extensions to install |
| `my.programs.firefox.extensionsInstallMode` | `"force_installed"` | Policy install mode |
| `my.programs.firefox.blockUnknownExtensions` | `true` | Block unlisted add-ons |
| `my.programs.firefox.bookmarks` | (Nix bookmarks) | Bookmark configuration |
| `my.programs.firefox.forceBookmarks` | `true` | Overwrite existing bookmarks |
| `my.programs.firefox.enableGnomeExtensions` | `false` | GNOME native host connector |

## Usage

```nix
my.programs.firefox = {
  enable = true;
  extensions = [ "ublock-origin" "1password" ];
};
```

## Add a New Extension

1. Find the addon on [addons.mozilla.org](https://addons.mozilla.org)
2. Note the **short ID** from the URL slug (e.g. `ublock-origin`)
3. Get the addon **GUID** — install it manually once, then visit
   `about:support` → Add-ons and copy the ID, or run:
   ```bash
   curl -s "https://addons.mozilla.org/api/v5/addons/addon/<short-id>/" | jq '.guid'
   ```
4. Add an entry to `modules/home/firefox/extensions.nix` with the `guid` and `shortId`
