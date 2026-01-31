# Infrastructure as Code (IaC) with automated deployment pipelines

# Objective
To design and implement an automated infrastructure deployment pipeline that eliminates manual provisioning, reduces deployment time, and ensures consistency across environments.

# Problem Statement
Traditional infrastructure management involves:

•	Manual server provisioning leading to human errors

•	Inconsistent configurations across environments

•	Time-consuming deployment processes

•	Difficulty in scaling infrastructure

•	Lack of version control for infrastructure changes

•	Complex rollback procedures

# Solution Approach
# Implement Infrastructure as Code (IaC) with automated deployment pipelines to achieve:

•	Codified infrastructure that can be version controlled

•	Automated, repeatable deployments

# Pre-Setup
**1. Start Jenkins**

bash# Windows

net start jenkins

# Linux
sudo systemctl start jenkins

sudo systemctl status jenkins

#2. Verify AWS Credentials

bashaws sts get-caller-identity

aws configure list

# 3. Check Repository Access

bashgit remote -v

git pull origin main

# Part 1: Code Review (Check in Browser/IDE)
Files to Show:

Jenkinsfile - Pipeline definition

terraform/main.tf - Infrastructure code

ansible/docker_install_on_ubuntu.yaml - Configuration automation


# Part 2: Jenkins Pipeline Execution
Access Jenkins

http://localhost:8080

Trigger Build

Navigate to job: "AWS-Infrastructure-Pipeline"

Click "Build with Parameters"

Select ACTION: "apply"

Click "Build"

# Monitor Console Output

Click on build number

Click "Console Output"

Watch stages execute


# Part 3: AWS Verification Commands
List EC2 Instances

bashaws ec2 describe-instances --region ap-south-1 \

  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  
  --output table

Get Instance IDs

bash# Get all instance IDs

aws ec2 describe-instances --region ap-south-1 \

  --query 'Reservations[*].Instances[*].InstanceId' \
  
  --output text

# Store in variables (Linux/Mac)

export UBUNTU_ID=$(aws ec2 describe-instances --region ap-south-1 \

  --filters "Name=tag:Name,Values=*ubuntu*" \
  
  --query 'Reservations[0].Instances[0].InstanceId' \
  
  --output text)

export AMAZON_ID=$(aws ec2 describe-instances --region ap-south-1 \

  --filters "Name=tag:Name,Values=*amazon*" \
  
  --query 'Reservations[0].Instances[0].InstanceId' \
  
  --output text)

echo "Ubuntu Instance: $UBUNTU_ID"

echo "Amazon Instance: $AMAZON_ID"

Check Instance Status
bashaws ec2 describe-instance-status --region ap-south-1 \
  --instance-ids $UBUNTU_ID $AMAZON_ID
View Security Groups
bashaws ec2 describe-security-groups --region ap-south-1 \
  --filters "Name=vpc-id,Values=YOUR_VPC_ID" \
  --query 'SecurityGroups[*].[GroupId,GroupName,Description]' \
  --output table
View VPC Configuration
bashaws ec2 describe-vpcs --region ap-south-1 \
  --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
  --output table

Part 4: SSM and Docker Verification
Check SSM Agent Status
bashaws ssm describe-instance-information --region ap-south-1 \
  --query 'InstanceInformationList[*].[InstanceId,PingStatus,AgentVersion]' \
  --output table
Verify Docker Installation
bash# Ubuntu instance
aws ssm send-command \
  --region ap-south-1 \
  --instance-ids $UBUNTU_ID \
  --document-name "AWS-RunShellScript" \
  --parameters commands=["docker --version","docker ps","sudo systemctl status docker"] \
  --output text

# Amazon Linux instance
aws ssm send-command \
  --region ap-south-1 \
  --instance-ids $AMAZON_ID \
  --document-name "AWS-RunShellScript" \
  --parameters commands=["docker --version","docker ps","sudo systemctl status docker"] \
  --output text
Get Command Output
bash# List recent commands
aws ssm list-commands --region ap-south-1 \
  --max-results 5 \
  --query 'Commands[*].[CommandId,DocumentName,Status]' \
  --output table

# Get specific command output
aws ssm get-command-invocation \
  --region ap-south-1 \
  --command-id "COMMAND_ID_FROM_ABOVE" \
  --instance-id $UBUNTU_ID
Start SSM Session (Interactive)
bash# Ubuntu
aws ssm start-session --target $UBUNTU_ID

# Amazon Linux
aws ssm start-session --target $AMAZON_ID

# Once in session:

docker --version

docker ps

exit
