{
  name = "installer-iso";
  description = "Custom NixOS installer ISO with Tailscale auto-connect and pre-seeded SSH keys for headless deployment via Ventoy";
  category = "tool";
  hostPlatform = "x86_64-linux";
  documentation = ''
    Build with: just build-iso
    This produces a NixOS minimal installer ISO that:
    - Auto-connects to Tailscale on boot
    - Accepts SSH connections with your pre-configured public key
    - Uses a consistent SSH host key (pre-generated)
    
    Place the resulting ISO on a Ventoy USB alongside other ISOs (Windows, etc.)
    to have a multi-boot installation USB.
  '';
}
