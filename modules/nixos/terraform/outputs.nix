# terraform/outputs.nix
{ ... }:

{
  output = {
    instance_id = {
      description = "EC2 instance ID";
      value       = "\${aws_instance.main.id}";
    };

    public_ip = {
      description = "Public IP of the instance";
      value       = "\${aws_instance.main.public_ip}";
    };

    public_dns = {
      description = "Public DNS of the instance";
      value       = "\${aws_instance.main.public_dns}";
    };

    vpc_id = {
      description = "VPC ID";
      value       = "\${aws_vpc.main.id}";
    };
  };
}
