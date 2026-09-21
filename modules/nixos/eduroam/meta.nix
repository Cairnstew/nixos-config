{
  name = "eduroam";
  description = "Declarative eduroam (WPA2-Enterprise) WiFi via NetworkManager ensureProfiles + agenix secrets; bakes the password into the volatile keyfile at boot so NM never prompts";
  category = "networking";
  tags = [ "wifi" "eduroam" "802.1x" "wpa-eap" "networkmanager" ];
  provides = [ "my.networking.eduroam" ];
  complexity = "simple";
  tested = true;
}
