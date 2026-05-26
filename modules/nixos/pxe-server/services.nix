{ lib, config, pkgs, ... }:
let
  cfg = config.my.services.pxeServer;
in
{
  systemd.services.pxe-setup = lib.mkIf cfg.enable {
    description = "PXE Server — deploy boot files";
    after = [ "network.target" "nginx.service" ];
    wants = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    before = [ "dnsmasq.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /srv/tftp/ipxe /srv/pxe/windows

      if [ ! -f /srv/tftp/ipxe.efi ]; then
        cp ${pkgs.ipxe}/ipxe.efi /srv/tftp/ipxe.efi
      fi

      if [ ! -f /srv/tftp/undionly.kpxe ]; then
        cp ${pkgs.ipxe}/undionly.kpxe /srv/tftp/undionly.kpxe
      fi

      if [ ! -f /srv/tftp/wimboot ]; then
        cp ${pkgs.wimboot}/share/wimboot/wimboot.x86_64.efi /srv/tftp/wimboot
      fi

      cp ${./boot.ipxe} /srv/tftp/ipxe/boot.ipxe
    '';
  };
}
