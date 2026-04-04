output "aws_hosts" {
  description = "Public IPs of all AWS hosts"
  value = {
    for k, mod in module.aws : k => mod.public_ip
  }
}