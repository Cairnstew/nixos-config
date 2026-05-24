# RStudio

RStudio IDE with custom R packages via `rstudioWrapper`, plus fonts, LaTeX, and Chromium for pagedown.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable RStudio for this user |
| `package` | package | `pkgs.rstudioWrapper` | The RStudio package to use |
| `rPackages` | list of package | [ggplot2, dplyr, tidyr, …] | R packages bundled with RStudio |
| `extraPackages` | list of package | [ ] | Extra packages to install alongside RStudio |

## Usage

```nix
my.programs.rstudio.enable = true;
```

### With extra R packages

```nix
my.programs.rstudio = {
  enable = true;
  rPackages = with pkgs.rPackages; [
    ggplot2
    dplyr
    tidyr
  ];
};
```

## Notes

- Uses `rstudioWrapper` to bundle custom R packages into the RStudio package.
- Installs JetBrains Mono and Fira Code Nerd Fonts for the RStudio editor.
- Installs `texlive.combined.scheme-full` for LaTeX support (e.g., knitting to PDF).
- Installs `chromium` for RStudio pagedown HTML rendering.
