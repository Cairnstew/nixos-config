output "public_ip" {
  value = aws_eip.this.public_ip
}

output "instance_id" {
  value = aws_instance.this.id
}

output "ami_id" {
  value = data.aws_ami.nixos.id
}
