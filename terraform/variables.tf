variable "project_name" {
  description = "Project name"
  type        = string
  default     = "Terraform-Ansible-Jenkins"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "amazon_linux_host_count" {
  description = "Number of Amazon Linux hosts"
  type        = number
  default     = 1
}

variable "ubuntu_host_count" {
  description = "Number of Ubuntu hosts"
  type        = number
  default     = 1
}

variable "sg_ports" {
  description = "List of ports for security group"
  type        = list(any)
  default = [
    { port = 22, protocol = "tcp" },
    { port = 80, protocol = "tcp" },
    { port = 443, protocol = "tcp" },
    { port = -1, protocol = "icmp" }
  ]
}
