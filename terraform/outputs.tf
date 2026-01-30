output "amazon_linux_instance_id" {
  value = aws_instance.amazon_linux_host[*].id
}

output "ubuntu_instance_id" {
  value = aws_instance.ubuntu_host[*].id
}

output "amazon_linux_public_ip" {
  value = aws_instance.amazon_linux_host[*].public_ip
}

output "ubuntu_public_ip" {
  value = aws_instance.ubuntu_host[*].public_ip
}
