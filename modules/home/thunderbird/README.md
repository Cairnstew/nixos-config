# Thunderbird

Mozilla Thunderbird email client with Home Manager integration.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.thunderbird.enable` | `false` | Enable Thunderbird email client |
| `my.programs.thunderbird.package` | `pkgs.thunderbird` | The Thunderbird package to install |
| `my.programs.thunderbird.username` | `config.home.username` | Username for Thunderbird profile |
| `my.programs.thunderbird.email` | `""` | Default email address (empty = no pre-configuration) |
| `my.programs.thunderbird.profileName` | `"default"` | Name of the Thunderbird profile |
| `my.programs.thunderbird.settings` | `{ }` | Thunderbird preferences to set |

## Usage Example

```nix
my.programs.thunderbird = {
  enable = true;
  email = "user@example.com";
  profileName = "personal";
  settings = {
    "general.useragent.locale" = "en-US";
  };
};
```

## Notes

- This module uses Home Manager's `programs.thunderbird` for configuration.
- The profile is automatically set as the default profile.
- For complex email account configuration, use Thunderbird's built-in account setup wizard.

## Upstream Documentation

- [Thunderbird Website](https://www.thunderbird.net)
- [Home Manager Thunderbird Options](https://nix-community.github.io/home-manager/options.html#opt-programs.thunderbird.enable)
