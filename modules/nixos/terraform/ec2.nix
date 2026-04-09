# terraform/ec2.nix
{ ... }:

{
  resource.aws_instance.main = {
    ami                    = "\${var.ami_id}";
    instance_type          = "\${var.instance_type}";
    subnet_id              = "\${aws_subnet.public.id}";
    vpc_security_group_ids = [ "\${aws_security_group.main.id}" ];

    # Only set key_name when the variable is non-empty
    key_name = "\${var.key_name != \"\" ? var.key_name : null}";

    root_block_device = [{
      volume_size           = 20;
      volume_type           = "gp3";
      delete_on_termination = true;
    }];

    tags.Name = "main";
  };
}
