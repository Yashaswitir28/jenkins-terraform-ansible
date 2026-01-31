# Demo Commands Quick Reference

## Pre-Demo Setup

### 1. Start Jenkins
```bash
# Windows
net start jenkins

# Linux
sudo systemctl start jenkins
sudo systemctl status jenkins
```

### 2. Verify AWS Credentials
```bash
aws sts get-caller-identity
aws configure list
```

### 3. Check Repository Access
```bash
git remote -v
git pull origin main
```

---

## Part 1: Code Review (Show in Browser/IDE)

### Files to Show:
1. **Jenkinsfile** - Pipeline definition
2. **terraform/main.tf** - Infrastructure code
3. **ansible/docker_install_on_ubuntu.yaml** - Configuration automation

---

## Part 2: Jenkins Pipeline Execution

### Access Jenkins
```
http://localhost:8080
```

### Trigger Build
1. Navigate to job: "AWS-Infrastructure-Pipeline"
2. Click "Build with Parameters"
3. Select ACTION: "apply"
4. Click "Build"

### Monitor Console Output
- Click on build number
- Click "Console Output"
- Watch stages execute

---

## Part 3: AWS Verification Commands

### List EC2 Instances
```bash
aws ec2 describe-instances --region ap-south-1 \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

### Get Instance IDs
```bash
# Get all instance IDs
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
```

### Check Instance Status
```bash
aws ec2 describe-instance-status --region ap-south-1 \
  --instance-ids $UBUNTU_ID $AMAZON_ID
```

### View Security Groups
```bash
aws ec2 describe-security-groups --region ap-south-1 \
  --filters "Name=vpc-id,Values=YOUR_VPC_ID" \
  --query 'SecurityGroups[*].[GroupId,GroupName,Description]' \
  --output table
```

### View VPC Configuration
```bash
aws ec2 describe-vpcs --region ap-south-1 \
  --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

---

## Part 4: SSM and Docker Verification

### Check SSM Agent Status
```bash
aws ssm describe-instance-information --region ap-south-1 \
  --query 'InstanceInformationList[*].[InstanceId,PingStatus,AgentVersion]' \
  --output table
```

### Verify Docker Installation
```bash
# Ubuntu instance
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
```

### Get Command Output
```bash
# List recent commands
aws ssm list-commands --region ap-south-1 \
  --max-results 5 \
  --query 'Commands[*].[CommandId,DocumentName,Status]' \
  --output table

# Get specific command output
aws ssm get-command-invocation \
  --region ap-south-1 \
  --command-id "COMMAND_ID_FROM_ABOVE" \
  --instance-id $UBUNTU_ID
```

### Start SSM Session (Interactive)
```bash
# Ubuntu
aws ssm start-session --target $UBUNTU_ID

# Amazon Linux
aws ssm start-session --target $AMAZON_ID

# Once in session:
docker --version
docker ps
exit
```

---

## Part 5: CloudWatch Monitoring

### List Metrics
```bash
# EC2 metrics
aws cloudwatch list-metrics \
  --namespace AWS/EC2 \
  --region ap-south-1 \
  --query 'Metrics[*].[MetricName,Dimensions[0].Value]' \
  --output table
```

### Get CPU Metrics
```bash
aws cloudwatch get-metric-statistics \
  --region ap-south-1 \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$UBUNTU_ID \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --query 'Datapoints[*].[Timestamp,Average]' \
  --output table
```

### View CloudWatch Logs
```bash
# List log groups
aws logs describe-log-groups --region ap-south-1 \
  --query 'logGroups[*].logGroupName' \
  --output table

# Tail SSM logs
aws logs tail /aws/ssm/AWS-RunShellScript --region ap-south-1 --follow
```

---

## Part 6: Terraform State Inspection

### Navigate to Terraform Directory
```bash
cd terraform
```

### Show Current State
```bash
terraform show
```

### List Resources
```bash
terraform state list
```

### Show Specific Resource
```bash
terraform state show aws_instance.ubuntu
terraform state show aws_instance.amazon_linux
```

### View Outputs
```bash
terraform output
terraform output ubuntu_instance_id
terraform output ubuntu_public_ip
```

---

## Part 7: Git Repository Verification

### View Deployment Summary
```bash
cat deployment-summary.txt
```

### Check Git History
```bash
git log --oneline -10
git log --grep="deployment summary" --oneline
```

### View Recent Commits
```bash
git log --since="1 day ago" --oneline
git show HEAD
```

---

## Part 8: Cleanup/Destroy

### Trigger Destroy in Jenkins
1. Build with Parameters
2. Select ACTION: "destroy"
3. Click Build
4. Approve destruction when prompted

### Verify Destruction (AWS)
```bash
# Check for running instances
aws ec2 describe-instances --region ap-south-1 \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# List VPCs
aws ec2 describe-vpcs --region ap-south-1 \
  --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

### Manual Cleanup (if needed)
```bash
cd terraform
terraform destroy -auto-approve
```

---

## Troubleshooting Commands

### If Pipeline Fails at Terraform Stage
```bash
cd terraform
terraform init -upgrade
terraform validate
terraform plan
```

### If SSM Commands Don't Work
```bash
# Check IAM role
aws iam get-role --role-name SSMRole

# Check instance profile
aws ec2 describe-instances --instance-ids $UBUNTU_ID \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'

# Restart SSM agent (via session manager)
aws ssm start-session --target $UBUNTU_ID
sudo systemctl restart amazon-ssm-agent
exit
```

### If Instances Not Accessible
```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids YOUR_SG_ID \
  --query 'SecurityGroups[0].IpPermissions'

# Check route table
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=YOUR_VPC_ID"

# Check internet gateway
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=YOUR_VPC_ID"
```

---

## Demo Flow Summary

1. ✓ Show code in GitHub/IDE (2 min)
2. ✓ Trigger Jenkins pipeline (1 min)
3. ✓ Monitor pipeline execution (6 min)
4. ✓ Verify AWS resources created (3 min)
5. ✓ Check Docker installation (2 min)
6. ✓ Show CloudWatch metrics (2 min)
7. ✓ View deployment summary in Git (1 min)
8. ✓ Trigger cleanup (2 min)
9. ✓ Q&A (5 min)

**Total Time: ~20 minutes**

---

## Quick Reference Tables

### AWS Region Codes
| Region Name | Code |
|-------------|------|
| Mumbai | ap-south-1 |
| Singapore | ap-southeast-1 |
| Tokyo | ap-northeast-1 |
| US East (N. Virginia) | us-east-1 |

### Instance States
| State | Meaning |
|-------|---------|
| pending | Instance starting |
| running | Instance active |
| stopping | Instance shutting down |
| stopped | Instance stopped |
| terminated | Instance deleted |

### Common Ports
| Service | Port |
|---------|------|
| HTTP | 80 |
| HTTPS | 443 |
| SSH | 22 |
| RDP | 3389 |

---

## Emergency Contacts & Resources

- AWS Support: [AWS Console → Support](https://console.aws.amazon.com/support)
- Jenkins Documentation: https://www.jenkins.io/doc/
- Terraform Registry: https://registry.terraform.io/
- GitHub Repository: https://github.com/Yashaswitir28/jenkins-terraform-ansible

---

**Last Updated**: January 31, 2026
**For**: Final Year Project Demo
