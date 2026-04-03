{ ... }: {
  my.cloud-vm = {
    enable = true;
    provider = "aws";
    profile = "web";
  };

  networking.hostName = "aws-webserver";
}