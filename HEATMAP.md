# Task Heatmap

Quick reference for common maintenance tasks. Lists files to read and edit in order.

---

## Add a new NixOS host

**Read:**
1. `AGENTS.md` (§3.1 Quick Start, §6 Configuration Conventions)
2. `configurations/nixos/laptop/default.nix` (reference implementation)
3. `modules/nixos/common.nix` (to understand what's imported)

**Edit:**
1. `configurations/nixos/<hostname>/default.nix` (create new)
2. `configurations/nixos/<hostname>/hardware-configuration.nix` (create new, generate with `nixos-generate-config`)

---

## Add a new nix-darwin host

**Read:**
1. `AGENTS.md` (§3.1, check darwin is mentioned)
2. `flake.nix` (see available inputs and systems)

**Edit:**
1. `configurations/darwin/<hostname>.nix` (create new)

---

## Add a new Home Manager standalone config

**Read:**
1. `configurations/home/seanc@laptop.nix` (reference implementation)
2. `modules/home/default.nix` (see available home modules)

**Edit:**
1. `configurations/home/<username>@<hostname>.nix` (create new)

---

## Create a new my.* NixOS module

**Read:**
1. `modules/AGENT.md` (full module structure specification)
2. `modules/nixos/template.nix` (minimal starting point)
3. `modules/nixos/docker/default.nix` (complete directory example)
4. `modules/nixos/docker/options.nix` (option declaration patterns)
5. `modules/nixos/docker/meta.nix` (metadata schema)

**Edit:**
1. `modules/nixos/<name>/default.nix` (create - import manifest only)
2. `modules/nixos/<name>/options.nix` (create - declare `my.*` options)
3. `modules/nixos/<name>/config.nix` (create - implementation)
4. `modules/nixos/<name>/meta.nix` (create - machine-readable contract)
5. `modules/nixos/<name>/tests.nix` (create - L0 assertions minimum)
6. `modules/nixos/<name>/README.md` (create - human documentation)

---

## Enable an existing profile for a host

**Read:**
1. `configurations/nixos/laptop/default.nix` (see how profiles are enabled)
2. `modules/nixos/profiles/system/default.nix` (available system profiles)
3. `modules/nixos/profiles/home/default.nix` (available home profiles)

**Edit:**
1. `configurations/nixos/<hostname>/default.nix` (add `my.profiles.<name>.enable = true;` or `my.homeProfiles.<name>.enable = true;`)

---

## Add a new package to packages/

**Read:**
1. `modules/flake-parts/packages.nix` (see how packages are exported)
2. `packages/copy-md-as-html.nix` (simple package example)
3. `packages/complex-app/default.nix` (directory package example)

**Edit:**
1. `packages/<name>.nix` (create new, or `packages/<name>/default.nix` for complex packages)

---

## Add a new overlay

**Read:**
1. `overlays/default.nix` (see current overlays)

**Edit:**
1. `overlays/default.nix` (add overlay function to the attrset)

---

## Add a new agenix secret and wire it to a module

**Read:**
1. `secrets/secrets.nix` (see existing secret definitions)
2. `modules/nixos/secrets/catalog.nix` (secret catalog schema)
3. `modules/nixos/secrets/options.nix` (how secrets are declared)
4. Target module that will consume the secret (e.g., `modules/nixos/gitreposync/options.nix` for `agenix.enable` pattern)

**Edit:**
1. `secrets/secrets.nix` (add new secret entry with recipients)
2. `modules/nixos/secrets/catalog.nix` (add to catalog if using catalog pattern)
3. Create `secrets/<name>.age` (encrypt with `agenix -e secrets/<name>.age`)
4. Target module `options.nix` (add `secretPath` or similar option if needed)
5. Target module `config.nix` (wire `config.age.secrets.<name>.path` to service)

---

# Option Registry

All `my.*` options declared across module files.

## my.profiles.* (System Profiles)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.profiles.workstation.enable` | bool | `false` | Workstation profile (desktop/laptop) |
| `my.profiles.server.enable` | bool | `false` | Server profile (headless) |
| `my.profiles.minimal.enable` | bool | `false` | Minimal profile (bare essentials) |
| `my.profiles.gaming.enable` | bool | `false` | Gaming profile (Steam, games, etc.) |
| `my.profiles.development.enable` | bool | `false` | Development profile (dev tools, containers) |
| `my.profiles.desktop.gnome.enable` | bool | `false` | GNOME desktop environment |
| `my.profiles.desktop.plasma.enable` | bool | `false` | KDE Plasma desktop environment |
| `my.profiles.gpu.mesa.enable` | bool | `false` | Mesa GPU drivers (Intel/AMD) |
| `my.profiles.gpu.nvidia.enable` | bool | `false` | NVIDIA GPU drivers (full desktop) |
| `my.profiles.gpu.nvidia-headless.enable` | bool | `false` | NVIDIA GPU drivers (headless/CUDA) |
| `my.profiles.location.enable` | bool | `false` | Location services (timezone, geoclue) |
| `my.profiles.battery.enable` | bool | `false` | Battery/power management |

## my.homeProfiles.* (Home Profiles)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.homeProfiles.common.enable` | bool | `false` | Common home profile (shell, basic tools) |
| `my.homeProfiles.desktop.enable` | bool | `false` | Desktop home profile (GUI apps) |
| `my.homeProfiles.development.enable` | bool | `false` | Development home profile (dev tools) |
| `my.homeProfiles.minimal.enable` | bool | `false` | Minimal home profile (essential only) |
| `my.homeProfiles.server.enable` | bool | `false` | Server home profile (SSH tools) |

## my.programs.* (User Programs)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.programs.spotify.enable` | bool | `false` | Spotify music client |
| `my.programs.ventoy.enable` | bool | `false` | Ventoy bootable USB creator |
| `my.ventoy.enable` | bool | `false` | Contribute ISOs to Ventoy USB |
| `my.ventoy.isos` | attrs | `{}` | ISOs this host contributes to Ventoy USB |
| `my.programs.uup-converter.enable` | bool | `false` | Windows ISO conversion tool |
| `my.programs.whatsapp-electron.enable` | bool | `false` | WhatsApp Electron client |
| `my.programs.udiskie.enable` | bool | `false` | Udiskie automount daemon |
| `my.programs.ghostty.enable` | bool | `false` | Ghostty terminal emulator |
| `my.programs.ghostty.enableSystemd` | bool | `true` | Enable systemd service for Ghostty |
| `my.programs.ghostty.package` | package | `pkgs.ghostty` | Ghostty package to use |
| `my.programs.ghostty.fontSize` | int | `12` | Font size |
| `my.programs.ghostty.windowWidth` | int | `100` | Window width in columns |
| `my.programs.ghostty.windowHeight` | int | `30` | Window height in rows |
| `my.programs.ghostty.theme` | str | `"catppuccin-mocha"` | Color theme |
| `my.programs.ghostty.gtkTitlebar` | bool | `false` | Use GTK titlebar |
| `my.programs.ghostty.clearDefaultKeybinds` | bool | `true` | Clear default keybindings |
| `my.programs.ghostty.keybindings` | attrs | `{}` | Keybinding configuration |
| `my.programs.gh.enable` | bool | `false` | GitHub CLI |
| `my.programs.just.enable` | bool | `false` | Just command runner |
| `my.programs.vscode.enable` | bool | `false` | VSCode editor |
| `my.programs.zsh.enable` | bool | `false` | Zsh shell |
| `my.programs.bash.enable` | bool | `false` | Bash shell |
| `my.programs.localsend.enable` | bool | `false` | LocalSend file sharing |
| `my.programs.discord.enable` | bool | `false` | Discord client |
| `my.programs.aider.enable` | bool | `false` | Aider AI coding assistant |
| `my.programs.cudatext.enable` | bool | `false` | CudaText editor |
| `my.programs.freecad.enable` | bool | `false` | FreeCAD CAD software |
| `my.programs.thunderbird.enable` | bool | `false` | Thunderbird email client |
| `my.programs.thunderbird.email` | str | — | Email address |
| `my.programs.thunderbird.username` | str | — | Username for email |
| `my.programs.obsidian.enable` | bool | `false` | Obsidian note-taking |
| `my.programs.direnv.enable` | bool | `false` | direnv with nix-direnv |
| `my.programs.firefox.enable` | bool | `false` | Firefox browser |
| `my.programs.youtube-music.enable` | bool | `false` | YouTube Music client |
| `my.programs.steam.enable` | bool | `false` | Steam gaming platform (32-bit, unfree, system-wide) |
| `my.programs.steam.remotePlay.openFirewall` | bool | `false` | Open firewall for Steam Remote Play Together |
| `my.programs.steam.dedicatedServer.openFirewall` | bool | `false` | Open firewall for Steam dedicated servers |
| `my.programs.steam.gamemode.enable` | bool | `false` | Enable Feral Gamemode |
| `my.programs.steam.extraCompatPaths` | str? | `null` | Extra Proton compatibility tool paths |
| `my.programs.steam.extraPackages` | list | `[]` | Extra Steam-related packages |
| `my.programs.rstudio.enable` | bool | `false` | RStudio IDE |
| `my.programs.yazi.enable` | bool | `false` | Yazi terminal file manager |
| `my.programs.ssh-1password.enable` | bool | `false` | 1Password SSH agent |

## my.services.* (System Services)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.services.tailscale.enable` | bool | `false` | Tailscale mesh VPN |
| `my.services.tailscale.openFirewall` | bool | `true` | Open Tailscale UDP port |
| `my.services.tailscale.exitNode` | bool | `false` | Advertise as exit node |
| `my.services.tailscale.tags` | list | `[]` | Tailscale ACL tags |
| `my.services.tailscale.ssh.enable` | bool | `false` | Static SSH config for tailnet |
| `my.services.tailscale.ssh.user` | str | — | Local user for SSH config |
| `my.services.tailscale.ssh.publicKeyPath` | path | `null` | Path to Tailscale SSH public key |
| `my.services.tailscale.ssh.extraHostConfig` | lines | `""` | Extra SSH config lines |
| `my.services.ollama.enable` | bool | `false` | Ollama OCI container service |
| `my.services.ollama.image` | str | `"ollama/ollama:latest"` | Docker image |
| `my.services.ollama.dataDir` | str | `"/var/lib/ollama"` | Host data directory |
| `my.services.ollama.port` | port | `11434` | API port |
| `my.services.ollama.host` | str | `"127.0.0.1"` | Listen address |
| `my.services.ollama.backend` | enum | `"docker"` | OCI backend (docker/podman) |
| `my.services.ollama.models` | attrs | `{}` | Models to pull/configure |
| `my.services.ollama.gpu.enable` | bool | `false` | GPU passthrough |
| `my.services.ollama.gpu.type` | enum | `"nvidia"` | GPU type (nvidia/amd/intel) |
| `my.services.ollama.mcp.enable` | bool | `false` | MCP server for Cline |
| `my.services.ollama.mcp.port` | port | `3100` | MCP server port |
| `my.services.ollama.mcp.openFirewall` | bool | `false` | Open MCP port in firewall |
| `my.services.ssh.enable` | bool | `false` | SSH server |
| `my.services.ssh.keyType` | str | `"ed25519"` | SSH key type |
| `my.services.ssh.keyPath` | str | — | Path to SSH key |
| `my.services.ssh.email` | str | — | Email for key comments |
| `my.services.ssh.addKeysToAgent` | bool | `true` | Add keys to agent |
| `my.services.ssh.enableAgent` | bool | `false` | Enable SSH agent |
| `my.services.udisks2.enable` | bool | `false` | UDisks2 storage management |
| `my.services.udiskie.enable` | bool | `false` | Udiskie automount (user service) |
| `my.services.plasmaX11.enable` | bool | `false` | KDE Plasma X11 session |
| `my.services.natShare.enable` | bool | `false` | NAT sharing/network bridge |
| `my.services.natShare.wanInterface` | str | — | WAN interface name |
| `my.services.natShare.lanInterface` | str | — | LAN interface name |
| `my.services.nebula.enable` | bool | `false` | Nebula mesh VPN |
| `my.services.rustdesk.enable` | bool | `false` | RustDesk remote desktop |
| `my.services.brasero.enable` | bool | `false` | Brasero CD/DVD burning |
| `my.services.cachix-push.enable` | bool | `false` | Cachix binary cache pushing |
| `my.services.sillytavern.enable` | bool | `false` | SillyTavern AI chat |
| `my.services.gitRepoSync.enable` | bool | `false` | Git repository sync service |
| `my.services.gitRepoSync.user` | str | — | User for sync timers |
| `my.services.gitRepoSync.repos` | attrs | `{}` | Repositories to sync |
| `my.services.hedgedoc.enable` | bool | `false` | HedgeDoc collaborative markdown |
| `my.services.netboot.enable` | bool | `false` | PXE netboot server (DHCP+TFTP+HTTP) |
| `my.services.netboot.serveMode` | enum | `"cli"` | `"cli"` = interactive CLI tool, `"daemon"` = persistent services |
| `my.services.netboot.interface` | str | `"eth0"` | Network interface to bind to |
| `my.services.netboot.serverAddress` | str | `"192.168.100.1"` | Static IP for the PXE server |
| `my.services.netboot.subnetPrefix` | int | `24` | Subnet prefix length |
| `my.services.netboot.dhcpRange` | str | `"192.168.100.100,192.168.100.150"` | DHCP lease range |
| `my.services.netboot.dhcpLeaseTime` | str | `"12h"` | DHCP lease duration |
| `my.services.netboot.tftpRoot` | path | `"/srv/tftp"` | TFTP root directory |
| `my.services.netboot.httpRoot` | path | `"/srv/pxe"` | HTTP root directory |
| `my.services.netboot.windows.enable` | bool | `false` | Enable Windows installer PXE boot |
| `my.services.netboot.windows.bootDir` | path | `"/srv/pxe/windows"` | Windows boot files directory |
| `my.services.netboot.nixos.enable` | bool | `false` | Enable NixOS installer PXE boot |
| `my.services.netboot.nixos.ipxeUrl` | str | upstream URL | NixOS netboot iPXE URL |
| `my.services.netboot.nixos.label` | str | `"NixOS Unstable"` | Display name for NixOS stage |
| `my.services.netboot.machines` | attrs | `{}` | Per-machine netboot definitions |
| `machines.<name>.windows.unattended.enable` | bool | `false` | Unattended Windows install with autounattend.xml |
| `machines.<name>.windows.unattended.edition` | str | `"Windows 11 Pro"` | Windows edition to install |
| `machines.<name>.windows.unattended.localUser` | str | `"nixos"` | Local admin username |
| `machines.<name>.windows.unattended.password` | str | `"nixos"` | Plaintext admin password (exposed over HTTP) |
| `machines.<name>.windows.unattended.passwordFile` | path | `null` | Read password from file at eval time |
| `machines.<name>.windows.unattended.timeZone` | str | `"GMT Standard Time"` | Windows timezone |
| `machines.<name>.windows.unattended.computerName` | str | — | Windows computer name |
| `machines.<name>.windows.unattended.disableRecovery` | bool | `true` | Disable recovery partition |
| `machines.<name>.nixos.autoInstall.enable` | bool | `false` | Automated NixOS install via custom netboot |
| `machines.<name>.nixos.autoInstall.diskoConfig` | raw | `{}` | disko configuration attrset |
| `machines.<name>.nixos.autoInstall.nixosConfig` | str | `""` | NixOS module expression for target system |

## my.virtualisation.* (Virtualization)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.virtualisation.docker.enable` | bool | `false` | Docker container runtime |
| `my.virtualisation.docker.enableOnBoot` | bool | `true` | Start on boot |
| `my.virtualisation.docker.enableNvidiaContainerToolkit` | bool | `false` | NVIDIA Container Toolkit |
| `my.virtualisation.docker.package` | package | `pkgs.docker` | Docker package |
| `my.virtualisation.docker.extraOptions` | str | `""` | Extra daemon options |
| `my.virtualisation.docker.extraPackages` | list | `[]` | Extra packages in PATH |
| `my.virtualisation.docker.listenOptions` | list | `["/run/docker.sock"]` | Listen addresses |
| `my.virtualisation.docker.liveRestore` | bool | `true` | Keep containers running on restart |
| `my.virtualisation.docker.logDriver` | enum | `"journald"` | Logging driver |
| `my.virtualisation.docker.storageDriver` | null/enum | `null` | Storage driver |
| `my.virtualisation.docker.autoPrune.enable` | bool | `false` | Auto cleanup |
| `my.virtualisation.docker.dataRoot` | null/path | `null` | Data directory |
| `my.virtualisation.docker.rootless.enable` | bool | `false` | Rootless mode |
| `my.virtualisation.waydroid.enable` | bool | `false` | Waydroid Android container |

## my.system.* (System Settings)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.system.audio.enable` | bool | `false` | PipeWire audio |
| `my.system.bluetooth.enable` | bool | `false` | Bluetooth support |
| `my.system.location.enable` | bool | `false` | Timezone/geolocation |
| `my.system.location.timeZone` | str | — | Timezone (e.g., "GB") |
| `my.system.location.latitude` | float | — | Latitude for redshift |
| `my.system.location.longitude` | float | — | Longitude for redshift |
| `my.system.userDefaults.enable` | bool | `false` | User default applications |

## my.desktop.gnome.* (GNOME Desktop)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.desktop.gnome.enable` | bool | `false` | GNOME desktop |
| `my.desktop.gnome.favoriteApps` | list | — | Favorite apps in dash |
| `my.desktop.gnome.workspaceNames` | list | `[]` | Workspace names |
| `my.desktop.gnome.enableHotCorners` | bool | `true` | Hot corners |
| `my.desktop.gnome.backgroundImage` | path | `null` | Background image |
| `my.desktop.gnome.gtkTheme` | str | — | GTK theme |
| `my.desktop.gnome.iconTheme` | str | — | Icon theme |
| `my.desktop.gnome.cursorTheme` | str | — | Cursor theme |
| `my.desktop.gnome.fontName` | str | — | UI font |
| `my.desktop.gnome.fontMonospace` | str | — | Monospace font |
| `my.desktop.gnome.numWorkspaces` | int | `4` | Number of workspaces |

## my.secrets.* (Secrets Management)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.secrets.enable` | bool | `false` | Enable agenix secrets |
| `my.secrets.catalog` | attrs | `{}` | Secret catalog definitions |

## my.homeManager.* (Home Manager Integration)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.homeManager.enable` | bool | `false` | Enable Home Manager |
| `my.homeManager.extraConfig` | attrs | `{}` | Extra HM configuration |

## my.build.* (Build Configuration)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.build.default` | package | — | Default package target |

## my.testing.* (Testing Framework)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.testing.enable` | bool | `false` | Enable testing framework |

## my.programs.opencode.* (OpenCode AI Agent)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.programs.opencode.enable` | bool | `false` | OpenCode AI coding agent |
| `my.programs.opencode.package` | package | `pkgs.opencode` | Package |
| `my.programs.opencode.enableMcpIntegration` | bool | `false` | Forward MCP servers |
| `my.programs.opencode.model` | null/str | `null` | Default model shorthand |
| `my.programs.opencode.share` | null/enum | `null` | Session sharing mode |
| `my.programs.opencode.autoupdate` | null/bool/enum | `null` | Auto-update behavior |
| `my.programs.opencode.smallModel` | null/str | `null` | Lightweight task model |
| `my.programs.opencode.defaultAgent` | null/str | `null` | Default agent |
| `my.programs.opencode.shell` | null/str | `null` | Shell for terminal |
| `my.programs.opencode.snapshot` | null/bool | `null` | Track file changes |
| `my.programs.opencode.settings` | attrs | `{}` | Verbatim JSON config |
| `my.programs.opencode.context` | lines/path | `""` | Global instructions |
| `my.programs.opencode.commands` | attrs | `{}` | Custom slash-commands |
| `my.programs.opencode.agents` | attrs | `{}` | Agent configurations |
| `my.programs.opencode.themes` | attrs | `{}` | Custom themes |
| `my.programs.opencode.tui` | attrs | `{}` | TUI configuration |
| `my.programs.opencode.skills` | attrs | `{}` | Custom skills |
| `my.programs.opencode.tools` | attrs | `{}` | Custom tools |
| `my.programs.opencode.mcp` | attrs | `{}` | MCP server configs |
| `my.programs.opencode.extraPackages` | list | `[]` | Extra PATH packages |
| `my.programs.opencode.enableLsp` | bool | `false` | Enable LSP support |
| `my.programs.opencode.openai.keyFile` | null/path | `null` | OpenAI API key |
| `my.programs.opencode.anthropic.keyFile` | null/path | `null` | Anthropic API key |
| `my.programs.opencode.google.keyFile` | null/path | `null` | Google AI key |
| `my.programs.opencode.groq.keyFile` | null/path | `null` | Groq API key |
| `my.programs.opencode.mistral.keyFile` | null/path | `null` | Mistral API key |
| `my.programs.opencode.xai.keyFile` | null/path | `null` | xAI API key |
| `my.programs.opencode.together.keyFile` | null/path | `null` | Together AI key |
| `my.programs.opencode.openrouter.keyFile` | null/path | `null` | OpenRouter key |
| `my.programs.opencode.fireworks.keyFile` | null/path | `null` | Fireworks AI key |
| `my.programs.opencode.cerebras.keyFile` | null/path | `null` | Cerebras key |
| `my.programs.opencode.clarifai.patFile` | null/path | `null` | Clarifai PAT |
| `my.programs.opencode.opencode-go.keyFile` | null/path | `null` | OpenCode Go key |
| `my.programs.opencode.opencode-zen.keyFile` | null/path | `null` | OpenCode Zen key |
| `my.programs.opencode.azure.keyFile` | null/path | `null` | Azure OpenAI key |
| `my.programs.opencode.azure.endpoint` | null/str | `null` | Azure endpoint |
| `my.programs.opencode.azure.deployment` | null/str | `null` | Azure deployment |
| `my.programs.opencode.ollamaModels` | attrs | `{}` | Ollama models config |
| `my.programs.opencode.ollamaBaseURL` | str | `"http://127.0.0.1:11434/v1"` | Ollama URL |

## my.programs.aider.* (Aider AI)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.programs.aider.enable` | bool | `false` | Aider AI assistant |
| `my.programs.aider.package` | package | `pkgs.aider-chat` | Package |
| `my.programs.aider.model` | str | — | Default model |
| `my.programs.aider.apiKey` | str | — | API key |
| `my.programs.aider.settings` | attrs | `{}` | Additional settings |

## my.programs.cline.* (Cline VSCode Extension)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.programs.cline.enable` | bool | `false` | Cline AI coding |
| `my.programs.cline.package` | package | — | VSCode extension |
| `my.programs.cline.settings` | attrs | `{}` | Extension settings |

## my.services.sillytavern.presets.* (SillyTavern)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.services.sillytavern.presets.*` | attrs | — | Character presets |

## my.programs.direnv.secretFiles.* (direnv Secrets)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.programs.direnv.secretFiles.<name>.vars` | attrs | `{}` | Environment variables from secrets |
| `my.programs.direnv.secretFiles.<name>.paths` | attrs | `{}` | Path variables from secrets |
