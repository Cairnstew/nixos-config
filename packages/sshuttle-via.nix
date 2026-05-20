# =============================================================================
# sshuttle-via.nix — SSHuttle Proxy Wrapper
# =============================================================================
# Purpose: Convenience wrapper around sshuttle for proxying all traffic through
#          an SSH host (useful for VPN-like access to remote networks).
#
# Not in nixpkgs: Personal convenience wrapper script.
#
# Usage: sshuttle-via <hostname>
# =============================================================================

{ writeShellApplication, sshuttle, ... }:

writeShellApplication {
  name = "sshuttle-via";
  meta = {
    description = "Proxy all traffic through an SSH host using sshuttle";
    longDescription = ''
      A convenience wrapper around sshuttle that sets up a transparent proxy
      for all traffic (0/0) through a specified SSH host. Useful for quick
      VPN-like access to remote networks without setting up a full VPN.
      
      Usage: sshuttle-via <hostname>
      Example: sshuttle-via myserver
    '';
    homepage = "https://sshuttle.readthedocs.io/";
    license = "MIT";
    mainProgram = "sshuttle-via";
  };
  runtimeInputs = [ sshuttle ];
  text = ''
    set -x
    sshuttle -r "$1" 0/0
  '';
}
