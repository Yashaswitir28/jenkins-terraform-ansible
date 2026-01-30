### Use the `terraform.tfvars` file to set variables as per your needs

```
project_name            = "jenkins-terraform-ansible"
instance_type           = "t2.micro"
key_name                = "ec2-ssh-key"
amazon_linux_host_count = 1
ubuntu_host_count       = 1
sg_ports = [
  {
    "port" : 22,
    "protocol" : "tcp"
  },
  {
    "port" : -1,
    "protocol" : "icmp"
  },
  {
    "port" : 443,
    "protocol" : "tcp"
  },
  {
    "port" : 80,
    "protocol" : "tcp"
  }
]
```

### Run following commands to deploy Instances on aws
```
# set aws credentials on aws cli
aws configure 

# Initilize the terraform
terraform init

# Check before deploy
terraform plan

# Deploy on aws
terraform apply --auto-approve
```