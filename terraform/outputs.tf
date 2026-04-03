output "instances" {
  description = "Deployed EC2 instances"
  value = {
    for name, instance in aws_instance.cloud_hosts :
    name => {
      id            = instance.id
      public_ip     = instance.public_ip_address
      private_ip    = instance.private_ip_address
      instance_type = instance.instance_type
      ami           = instance.ami
    }
  }
}

output "ssh_command" {
  description = "SSH command to connect to instances"
  value = {
    for name, instance in aws_instance.cloud_hosts :
    name => "ssh -i id_deployer.pem root@${instance.public_ip_address}"
  }
}

output "ssh_key_path" {
  description = "Path to the SSH private key"
  value       = local_sensitive_file.deployer_ssh_key.filename
  sensitive   = true
}
