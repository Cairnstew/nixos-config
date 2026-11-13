# Audio Stack Report

Generated: 2026-11-13 · Scope: the `my.*` audio stack in this flake, with a deep
dive on `desktop` · Method: source reading + `nix eval` of
`nixosConfigurations.desktop` + a read-only snapshot of the running desktop
(`wpctl status`, `systemctl --user`, `/etc/systemd/user`, store-rendered
WirePlumber drop-ins).

---

## 1. TL;DR

- One NixOS module owns the stack: **`modules/nixos/audio/`** (option namespace
  `my.system.audio`), imported by every host via `modules/nixos/common.nix:33`.
  It is **disabled by default** and switched on by the `workstation`, `gaming`
  and `entertainment` profiles (`mkDefault true`).
- The implementation is **PipeWire + WirePlumber**, with ALSA (incl. 32-bit),
  PulseAudio compatibility, **no** real PulseAudio daemon, **no** JACK, and
  `security.rtkit` for realtime scheduling.
- `desktop` turns on the optional layer: a **Pulsemeeter + EasyEffects virtual
  mixer** (`qpwgraph` patchbay), a **declared default microphone**, and a
  **per-device default volume boost** for the onboard Realtek analog jack.
- Bluetooth audio is configured in `modules/nixos/audio/config.nix` (codecs) and
  `modules/nixos/bluetooth.nix` (hardware, blueman, the `CAP_NET_ADMIN` fix).
- Runtime snapshot shows the stack healthy (PipeWire 1.6.9, WirePlumber 0.5.19,
  Pulsemeeter + EasyEffects running), with two drifts worth knowing about: the
  declared default mic is **not present** on the machine right now, and the
  onboard analog sink is running at restored state (105%) rather than its
  declared default (0.8 ≈ 93%). See §6.

---

## 2. Where the stack lives

| Path | Role |
|------|------|
| `modules/nixos/audio/default.nix` | Import manifest (`options` + `config` + `tests`) |
| `modules/nixos/audio/options.nix` | Declares `my.system.audio.*` |
| `modules/nixos/audio/config.nix` | PipeWire/WirePlumber config, packages, user services |
| `modules/nixos/audio/tests.nix` | Four assertions (see §3.8) |
| `modules/nixos/audio/meta.nix` | Module metadata (tags, `provides`) |
| `modules/nixos/audio/README.md` | User-facing docs for the options |
| `modules/nixos/common.nix:33` | `./audio` import — present on every NixOS host |
| `modules/nixos/hyprland/audio/` | Second, narrower PipeWire enable path (see §5) |
| `modules/nixos/bluetooth.nix` | Bluetooth hardware, `blueman`, capability fix |

The module is autowired as `nixosModules.audio`, but hosts do not import it
directly — they get it through `nixosModules.common`.

---

## 3. What the module configures (all hosts, when enabled)

### 3.1 PipeWire server

`modules/nixos/audio/config.nix:22-28`

| Setting | Value |
|---|---|
| `services.pipewire.enable` | `true` |
| `services.pipewire.audio.enable` | `true` |
| `services.pipewire.alsa.enable` | `true` |
| `services.pipewire.alsa.support32Bit` | `true` (Steam/Wine 32-bit games) |
| `services.pipewire.pulse.enable` | `true` (pulse-compat socket for pulsectl/Pulsemeeter) |
| `services.pipewire.jack.enable` | left at nixpkgs default `false` |
| `services.pulseaudio.enable` | **`false`** (`config.nix:74`) |
| `security.rtkit.enable` | `true` (`config.nix:76`) |

### 3.2 WirePlumber drop-ins

Rendered as `wireplumber.conf.d/*.conf` (verified on the running system under
`/nix/store/…-wireplumber-configs/share/wireplumber/wireplumber.conf.d/`).

| Drop-in | Content | Source |
|---|---|---|
| `10-bluez.conf` | `bluez5.enable-sbc-xq`, `enable-msbc`, `enable-hw-volume` = true; `bluez5.roles = [ a2dp_sink a2dp_source ]` | `config.nix:31-38` |
| `11-bluetooth-policy.conf` | `bluetooth.autoswitch-to-headset-profile = false` (don't drop A2DP when a mic opens) | `config.nix:39-41` |
| `12-device-default-volume.conf` | One `monitor.alsa.rules` entry per `deviceDefaultVolumes` entry, setting `device.routes.default-sink-volume` | `config.nix:43-56` |
| `10-default-source.conf` | `wireplumber.settings.default.audio.source = <mic.name>` | `config.nix:57-65` |

The per-device volume rule is matched on **`device.name`** (the card), not
`node.name`. Values are PipeWire's **linear** scale, so `0.8` displays as ≈93%
and `1.0` as 100% (`options.nix:10-23`).

### 3.3 Virtual mixer (opt-in)

`my.system.audio.virtualMixer` (`options.nix:45-86`, `config.nix:82-117`):

| Option | Default | Effect |
|---|---|---|
| `enable` | `false` | Adds `pulsemeeter`; enables the user services |
| `effects` | `true` | Adds `easyeffects` + its user service |
| `patchbay` | `none` | `qpwgraph` adds the graph editor |
| `autostart` | `true` | Installs `pulsemeeter` / `easyeffects` user units, `WantedBy=default.target` |
| `virtualSinks` | `[]` | Declarative `support.null-audio-sink` adapters in `pipewire.conf.d` |

User units (home-manager, systemd INI format — see GOTCHAS.md:520):

- `pulsemeeter`: `After=pipewire-pulse.service`, `Restart=on-failure`
- `easyeffects`: `After=pipewire.service pipewire-pulse.service`,
  `ExecStart=…/easyeffects --gapplication-service`

### 3.4 Packages

`config.nix:77-86` — `pavucontrol`, `blueman`, `pipewire`, `wireplumber`, plus
`pulsemeeter` / `easyeffects` / `qpwgraph` when the mixer is on. (PipeWire,
WirePlumber and Blueman also arrive from their own nixpkgs modules, so they
appear twice in the evaluated `systemPackages` list — harmless.)

### 3.5 Default microphone

`mic.enable` + `mic.name` are baked into WirePlumber at build time as
`default.audio.source` — no runtime `wpctl set-default` step. The node name
comes from `wpctl status` under "Sources" (`options.nix:26-43`).

### 3.6 Virtual sinks

Each entry becomes an `adapter` object with
`factory.name = support.null-audio-sink`, `media.class = Audio/Sink`, and
`audio.position` truncated to the requested channel count from
`FL FR FC LFE RL RR` (`config.nix:7-18, 68-72`). Requires a PipeWire restart on
activation.

### 3.7 Bluetooth (adjacent module)

`modules/nixos/bluetooth.nix`:

- `hardware.bluetooth.enable`, `powerOnBoot`, `AutoEnable`, `FastConnectable`
- `bluez`, `bluez-tools`, `bluez-alsa`
- `services.blueman.enable = true`
- **Capability fix** (`bluetooth.nix:37-38`): restores
  `CapabilityBoundingSet = CAP_NET_ADMIN CAP_NET_BIND_SERVICE` on
  `bluetooth.service`, because the nixpkgs unit strips `CAP_NET_ADMIN` and A2DP
  streaming then fails with `Permission denied (13)` in `avdtp_connect_cb`.

### 3.8 Assertions

`tests.nix` enforces:

1. `audio.enable` requires `services.pipewire.enable`.
2. `virtualMixer.enable` requires `audio.enable`.
3. `mic.enable` requires a non-null `mic.name`.
4. Every `deviceDefaultVolumes` value is within `[0.0, 1.0]`.

---

## 4. Desktop host

### 4.1 How it gets enabled

`configurations/nixos/desktop/default.nix:89-97` enables `workstation`,
`entertainment`, `gaming` (among others). Each of those sets
`my.system.audio.enable = lib.mkDefault true`
(`profiles/system/workstation.nix:15`, `gaming.nix:23`,
`entertainment.nix:11`). `workstation` also enables
`my.system.bluetooth.enable`.

### 4.2 Explicit overrides

`configurations/nixos/desktop/default.nix:128-150`:

```nix
my.system.audio = {
  deviceDefaultVolumes."alsa_card.pci-0000_09_00.4" = 0.8;   # onboard Realtek analog
  virtualMixer = { enable = true; patchbay = "qpwgraph"; };
  mic = {
    enable = true;
    name = "alsa_input.usb-C-Media_Electronics_Inc._USB_PnP_Sound_Device-00.analog-stereo";
    description = "USB headset";
  };
};
```

No `virtualSinks` are declared, so the only virtual sinks on this host come from
Pulsemeeter's runtime buses and EasyEffects' own sink.

### 4.3 Evaluated values (`nix eval`, this working tree)

```json
my.system.audio = {
  "enable": true,
  "deviceDefaultVolumes": { "alsa_card.pci-0000_09_00.4": 0.8 },
  "mic": { "enable": true, "description": "USB headset",
           "name": "alsa_input.usb-C-Media_Electronics_Inc._USB_PnP_Sound_Device-00.analog-stereo" },
  "virtualMixer": { "autostart": true, "effects": true, "enable": true,
                    "patchbay": "qpwgraph", "virtualSinks": [] }
}
```

- `services.pipewire.{enable,audio.enable,pulse.enable}` = `true`,
  `alsa = { enable = true; support32Bit = true; }`, `jack.enable = false`
- `services.pulseaudio.enable = false`, `security.rtkit.enable = true`,
  `services.blueman.enable = true`
- Merged WirePlumber drop-ins = the four listed in §3.2
- User services `pulsemeeter` + `easyeffects` installed for user `seanc`
- Evaluated audio packages: `pavucontrol-6.2`, `blueman-2.4.6`,
  `pipewire-1.6.9`, `wireplumber-0.5.19`, `pulsemeeter-2.2.0`,
  `easyeffects-8.3.2`, `qpwgraph-1.0.4`, `bluez-5.87`, `bluez-tools`,
  `bluez-alsa-4.3.1`, `playerctl-2.4.1`, `mpv-with-scripts-0.41.0`

### 4.4 Desktop-environment integration (Hyprland)

- **Media keys** — `modules/nixos/hyprland/core/config.nix:230-243`:
  - `XF86AudioRaiseVolume` → `wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+`
  - `XF86AudioLowerVolume` → `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-`
  - `XF86AudioMute` → `wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle`
  - `XF86AudioMicMute` → `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`
  - `XF86Audio{Play,Next,Prev,Stop}` → `playerctl …`
  (Volume is capped at 150% by the `-l 1.5` limit.)
- **Waybar** — `modules/nixos/hyprland/bar/config.nix:214-220`: `pulseaudio`
  module, `{icon} {volume}%`, mute state, tooltip with device description,
  `on-click = pavucontrol`.
- **Autostart** — `playerctld daemon` is in the desktop's `extraExecOnce`
  (`configurations/nixos/desktop/default.nix:230`).
- **Apps that produce audio** — via the `desktop` home profile
  (`modules/nixos/profiles/home/config.nix:27-40`): Spotify (+ TUI/now-playing
  widget), Discord, YouTube Music, OBS Studio, Firefox; plus `mpv` from the
  Hyprland utilities module (`hyprland/utilities/config.nix:40`).
- **OBS** is configured with `wlrobs` instead of the PipeWire screencast source
  (`desktop/default.nix:1343-1352`) — video capture, but it is the reason the
  portal/PipeWire capture path is not used.

### 4.5 Bluetooth audio on desktop

Onboard and USB audio plus Bluetooth are all live: `bluez5.roles` allows both
A2DP sink and source (so the desktop can act as a Bluetooth speaker too), and
`bluetooth.autoswitch-to-headset-profile = false` keeps music on A2DP when an
application opens the headset mic (HFP/HSP would otherwise switch profiles and
degrade quality).

---

## 5. Other hosts

| Host | `my.system.audio` | Notes |
|---|---|---|
| `desktop` | `true` | Full stack: mixer, mic, volume boost, qpwgraph |
| `laptop` | `true` | Via `workstation`; no mixer/mic/volume overrides; Hyprland audio submodule also on |
| `server` | `false` | Explicitly disabled by `profiles/system/server.nix:25` |
| `oracle` | `false` | `server` profile (same `mkDefault false`) |
| `minimal` | `false` | `minimal` profile never enables it; module default is `false` |
| `wsl` | `false` | `minimal` profile only |

**Second enable path.** `my.desktop.hyprland.audio` is enabled by default
whenever Hyprland is (`hyprland/enable.nix:19`), and its config sets
`services.pipewire.{enable,alsa,pulse}` and `security.rtkit.enable`
(`hyprland/audio/config.nix:8-15`). On `desktop` and `laptop` this overlaps
`my.system.audio` with identical values, so it is harmless — but it means a
Hyprland host would get bare PipeWire even with `my.system.audio.enable = false`
(no pavucontrol, no mixer, no mic policy). Today every Hyprland host enables
both.

---

## 6. Runtime snapshot (desktop, 2026-11-13)

Read-only checks on the live session:

- `pipewire` 1.6.9, `wireplumber` 0.5.19; `pipewire`, `pipewire-pulse`,
  `wireplumber`, `pulsemeeter`, `easyeffects` all `active`.
- Devices: `Starship/Matisse HD Audio Controller` (`pci-0000_09_00.4`),
  `Navi 21/23 HDMI/DP Audio Controller`, `Blue Snowball` (USB, ALSA),
  `WH-1000XM5` (Bluetooth).
- Default sink: **WH-1000XM5** at 33%.
- Onboard analog sink: `alsa_output.pci-0000_09_00.4.analog-stereo` at **105%**.
- Default source: **Blue Snowball** (`alsa_input.usb-BLUE_MICROPHONE_Blue_Snowball_201306-00.analog-stereo`)
  at 100%.
- EasyEffects filters present (`ee_sink_group`, `ee_source_group`,
  `easyeffects_sink`, `ee_sie_spectrum`, …); Pulsemeeter listener clients
  present.

### Findings / drift

1. **Declared default mic is inert right now.** The config declares
   `alsa_input.usb-C-Media_Electronics_Inc._USB_PnP_Sound_Device-00.analog-stereo`
   (`desktop/default.nix:146`) and it is baked into
   `10-default-source.conf`. That device is **not connected** (no C-Media node
   in `wpctl status -n`); WirePlumber therefore falls back to the Blue Snowball.
   The policy is correct, it just points at a headset that is currently
   unplugged. Re-check `wpctl status` and update `mic.name` if the headset was
   replaced.
2. **Onboard volume is restored state, not the declared default.** The rule sets
   `device.routes.default-sink-volume = 0.8` (≈93%) for
   `alsa_card.pci-0000_09_00.4`, but the sink currently runs at 105% because
   WirePlumber restored the last user-set volume. This is exactly the caveat
   documented in `audio/README.md:78-81` — `wpctl reset <id>` once to clear the
   stored state and pick up the declared default. 105% on a passive analog jack
   is above unity and can clip; if that was not intentional, reset it.
3. **EasyEffects is not in the default output path.** EasyEffects runs and
   exposes `easyeffects_sink`, but the default sink is the WH-1000XM5 directly,
   so effects only apply to streams routed into `easyeffects_sink` (or through
   Pulsemeeter buses). That is normal for this design — the mixer is an opt-in
   routing layer, not a system-wide filter.
4. **The audio graph is not reproducible from the flake.** The flake pins the
   stack, not the wiring: Pulsemeeter buses/volumes live in
   `~/.config/pulsemeeter/config.json` (currently one hardware sink "Main/Headphones"
   at 105), EasyEffects presets in `~/.config/easyeffects/` (no output preset
   present), and device state in `~/.local/state/wireplumber/`. `virtualSinks`
   is empty on desktop, so no declarative sinks exist. Reinstalling reproduces
   the services but not the routing.
5. **JACK is off.** `services.pipewire.jack.enable = false`, so JACK-only apps
   (Ardour, REAPER in JACK mode) would not see a JACK server. PipeWire's native
   and pulse-compat clients are unaffected.
6. **Two PipeWire enable paths** (see §5) — not a bug today, but any future host
   that enables Hyprland without `my.system.audio` gets a bare stack.

---

## 7. Verify / change

```bash
# what the stack looks like right now
wpctl status                 # devices, sinks, sources, filters
wpctl status -n              # full node names (for mic.name / device.name)
wpctl inspect @DEFAULT_AUDIO_SINK@ | grep -E 'node.name|device.name'
wpctl reset <id>             # clear restored state → pick up declared default volume
systemctl --user status pipewire pipewire-pulse wireplumber pulsemeeter easyeffects

# what the config says
nix eval .#nixosConfigurations.desktop.config.my.system.audio --json
nix eval .#nixosConfigurations.desktop.config.services.pipewire.wireplumber.extraConfig --json

# rendered drop-ins for the current generation
systemctl --user show wireplumber -p Environment --value | tr ' ' '\n' | grep XDG_DATA_DIRS
```

To change routing/effects permanently, add entries to
`my.system.audio.virtualMixer.virtualSinks` (declarative sinks) or commit the
Pulsemeeter/EasyEffects preset files — today neither is tracked.
