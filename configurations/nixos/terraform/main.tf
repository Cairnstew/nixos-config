# Provision the infrastructure
resource "aws_instance" "web" {
  ami           = "ami-xxxxxxxx" # Must be a NixOS AMI
  instance_type = "t3.micro"
  key_name      = "my-ssh-key"
}

# Apply the NixOS configuration
module "nixos_deploy" {
  source      = "github.com/nix-community/terraform-nixos//deploy_nixos?ref=master"
  
  target_host = aws_instance.web.public_ip
  target_user = "seanc"
  
  # Path to your nix config file
  nixos_config = "${path.module}/configuration.nix"
}