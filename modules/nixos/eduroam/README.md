# eduroam

Declarative eduroam (WPA2-Enterprise) WiFi via NetworkManager `ensureProfiles`
+ agenix secret. The password is baked into the volatile NM keyfile at every
boot so the connection auto-authenticates on every activation path — NM never
shows a password dialog.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.networking.eduroam.enable` | `false` | Enable eduroam WiFi profile |
| `my.networking.eduroam.identity` | — | EAP identity (student/staff email) |
| `my.networking.eduroam.passwordSecret` | `"eduroam-password"` | agenix secret name |
| `my.networking.eduroam.caCert` | `null` | CA cert path (null = system bundle) |
| `my.networking.eduroam.interface` | `null` | WiFi interface (null = auto) |
| `my.networking.eduroam.eap` | `"peap"` | EAP method |
| `my.networking.eduroam.phase2` | `"mschapv2"` | Phase-2 inner auth |
| `my.networking.eduroam.domain` | `null` | RADIUS cert domain-suffix-match |
| `my.networking.eduroam.pmf` | `1` | 802.11w Protected Management Frames |
| `my.networking.eduroam.autoconnectPriority` | `100` | NM autoconnect-priority |

## Usage Example

```nix
my.networking.eduroam = {
  enable = true;
  identity = "2012345@gcu.ac.uk";
  interface = "wlp170s0";
  domain = "gcu.ac.uk";
};
```

## Notes

- **Theory of operation:** `ensureProfiles` writes a passwordless profile to
  the volatile `/run/NetworkManager/system-connections/` at boot; a small
  oneshot (`my-networking-eduroam-inject`) then injects the password from the
  agenix secret and reloads NM. The plaintext therefore never touches the Nix
  store or `/etc/NetworkManager`.
- **Why both mechanisms:** NM only consults the file-secret-agent on
  *system-initiated* activation (boot-time auto-connect). If the user connects
  later by clicking the network in the GUI, the interactive agent (`nm-applet`)
  serves the request and shows a password dialog instead. Baking the password
  into the keyfile (which NM already rewrites there after a manual entry anyway)
  covers every activation path; the file-secret-agent remains as a boot-time
  fallback.
- **Roaming:** moving between APs on the same SSID does NOT need re-auth —
  `wpa_supplicant` keeps a PMKSA cache per SSID across campus APs.
- Set identity with `agenix-manager edit eduroam-password` if the university
  password changes.