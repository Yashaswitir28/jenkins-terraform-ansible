project_name            = "Terraform-Ansible-Jenkins"
instance_type           = "t2.micro"
key_name                = "ec2-ssh-key"
amazon_linux_host_count = 1
ubuntu_host_count       = 1
sg_ports = [
  {
    "port" : 443,
    "protocol" : "tcp"
  }
]
