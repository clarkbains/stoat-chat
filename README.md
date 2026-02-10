# Stoat Chat AWS Infrastructure

Complete infrastructure-as-code solution for deploying [Stoat Chat](https://github.com/stoatchat) (formerly Revolt) on AWS with automated GitHub Actions deployment.

## Features

- **Cost-Optimized**: Runs on ARM Graviton instances (~$17-23/month)
- **Scalable Storage**: Native S3 integration for media files
- **Automated Deployment**: GitHub Actions with OIDC authentication
- **Secure**: No long-lived AWS credentials, encrypted storage, automatic SSL
- **Production-Ready**: Remote Terraform state with locking

## Architecture

- **Compute**: EC2 t4g.small (ARM Graviton, 2 vCPUs, 2GB RAM)
- **Storage**: 30GB EBS (system) + S3 (media files)
- **Network**: VPC with public subnet, Elastic IP
- **DNS**: Route53 with automatic A record management
- **SSL**: Automatic Let's Encrypt certificates via Caddy
- **Database**: MongoDB (containerized)
- **Cache**: Redis + RabbitMQ (containerized)
- **CI/CD**: GitHub Actions with OpenID Connect (OIDC)

## Prerequisites

1. **AWS Account** with administrative access
2. **Route53 Hosted Zone** for your domain
3. **GitHub Repository** for this infrastructure code
4. **Local Tools**:
   - Terraform >= 1.0
   - AWS CLI configured
   - Git

## Repository Structure

```
stoat-infrastructure/
├── oidc-setup/              # Bootstrap: OIDC + Terraform state backend
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── infrastructure/          # Main Stoat Chat infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── user-data.sh        # EC2 bootstrap script
├── .github/
│   └── workflows/
│       └── terraform.yml   # CI/CD pipeline
├── .gitignore
└── README.md
```

## Quick Start

### Step 1: Bootstrap OIDC and State Backend

This is a one-time manual setup that creates the GitHub OIDC provider and Terraform state storage.

```bash
cd oidc-setup

# Create your configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Configure these values:
```hcl
aws_region  = "us-east-1"
github_org  = "your-github-username-or-org"
github_repo = "stoat-infrastructure"
```

Deploy the OIDC infrastructure:
```bash
terraform init
terraform plan
terraform apply
```

**Important**: Save these outputs - you'll need them:
- `github_actions_role_arn` - Add to GitHub secrets as `AWS_ROLE_ARN`
- `terraform_state_bucket` - Use in infrastructure backend config

### Step 2: Configure GitHub Secrets

In your GitHub repository, go to Settings → Secrets and variables → Actions:

Create a new secret:
- **Name**: `AWS_ROLE_ARN`
- **Value**: The `github_actions_role_arn` output from Step 1

### Step 3: Configure Main Infrastructure

```bash
cd ../infrastructure

# Create your configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Configure these values:
```hcl
aws_region   = "us-east-1"
domain_name  = "stoat.yourdomain.com"  # Must exist in Route53

# Optional customization
instance_type      = "t4g.small"
root_volume_size   = 30
allowed_ssh_cidr   = "YOUR.IP.ADDRESS/32"  # For debugging
```

Update the backend configuration in `main.tf`:
```hcl
backend "s3" {
  bucket         = "stoat-terraform-state-YOUR-ACCOUNT-ID"  # From Step 1
  key            = "stoat-chat/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "stoat-terraform-locks"
  encrypt        = true
}
```

### Step 4: Test Locally (Optional)

```bash
terraform init
terraform plan
```

This validates your configuration before pushing to GitHub.

### Step 5: Deploy via GitHub Actions

```bash
# Commit your configuration
git add .
git commit -m "Configure Stoat infrastructure"
git push origin main
```

GitHub Actions will automatically:
1. Run `terraform plan`
2. Apply the infrastructure
3. Deploy Stoat Chat

Check the Actions tab in GitHub to monitor progress.

### Step 6: Access Your Stoat Instance

After 10-15 minutes (for Docker images to download and services to start):

1. Visit `https://your-domain.com`
2. Create an account
3. Start chatting!

## Cost Breakdown

Monthly costs (us-east-1):

| Resource | Cost |
|----------|------|
| EC2 t4g.small (on-demand) | ~$12-13 |
| EBS gp3 30GB | ~$2.40 |
| S3 storage (50GB) | ~$1.15 |
| S3 requests | ~$0.01 |
| DynamoDB (state locking) | $0 (free tier) |
| Data transfer (5GB/month) | ~$0.40 |
| **Total** | **~$17-23/month** |

**Cost Optimization**:
- 1-year reserved instance: Save ~$4-5/month
- Use S3 Intelligent-Tiering: Auto-optimize storage costs
- Lightsail alternative: $12/month with 2TB data transfer included

## CI/CD Pipeline

### On Pull Request
- ✅ Runs `terraform fmt -check`
- ✅ Runs `terraform validate`
- ✅ Runs `terraform plan`
- ✅ Posts plan as PR comment

### On Push to Main
- ✅ Runs `terraform apply -auto-approve`
- ✅ Posts deployment status as commit comment

## Configuration Options

### Infrastructure Variables

**Required**:
- `aws_region` - AWS region for deployment
- `domain_name` - Domain name (must exist in Route53)

**Optional**:
- `instance_type` - Default: `t4g.small` (ARM)
  - Fallback: `t3.small` or `t3a.small` if ARM images unavailable
- `root_volume_size` - Default: `30` GB
- `s3_media_bucket_name` - Auto-generated if empty
- `allowed_ssh_cidr` - SSH access CIDR (default: disabled)
- `stoat_version` - Docker image tag (default: `latest`)

### Stoat Configuration

The user-data script automatically configures:
- **Database**: MongoDB connection
- **Cache**: Redis and RabbitMQ
- **Storage**: S3 with IAM instance profile (no credentials needed)
- **SSL**: Automatic Let's Encrypt via Caddy
- **Routing**: Caddy reverse proxy to services

## Troubleshooting

### Services Not Starting

Check EC2 user-data logs:
```bash
# SSH to instance (requires allowed_ssh_cidr)
ssh ubuntu@<instance-ip>

# Check user-data log
sudo tail -f /var/log/user-data.log

# Check Docker services
cd /opt/stoat
sudo docker compose ps
sudo docker compose logs -f
```

### SSL Certificate Issues

Caddy needs ports 80 and 443 open for Let's Encrypt:
```bash
# Check security group allows ports 80, 443
# Verify DNS resolves to your instance
dig +short your-domain.com

# Check Caddy logs
cd /opt/stoat
sudo docker compose logs caddy
```

### ARM Compatibility Issues

If Stoat images don't support ARM:
1. Update `infrastructure/terraform.tfvars`:
   ```hcl
   instance_type = "t3.small"  # x86 instance
   ```
2. Commit and push to trigger redeployment

### State Lock Issues

If Terraform state is locked:
```bash
# List locks in DynamoDB
aws dynamodb scan --table-name stoat-terraform-locks

# If stale, manually release (use with caution)
terraform force-unlock <LOCK_ID>
```

### Terraform Plan Shows Unexpected Changes

User data changes on every apply due to timestamps. Instance lifecycle ignores user_data changes:
```hcl
lifecycle {
  ignore_changes = [user_data, ami]
}
```

## Maintenance

### Updating Stoat Version

Edit `infrastructure/terraform.tfvars`:
```hcl
stoat_version = "20250930-2"  # Specific version tag
```

Commit and push to deploy the update.

### Scaling Up

For more users, increase instance size:
```hcl
instance_type = "t4g.medium"  # 2 vCPUs, 4GB RAM (~$24-26/month)
# or
instance_type = "t4g.large"   # 2 vCPUs, 8GB RAM (~$48-52/month)
```

### Backups

**Automated**:
- S3 media bucket has versioning enabled
- Terraform state has versioning enabled

**Manual Database Backup**:
```bash
ssh ubuntu@<instance-ip>
cd /opt/stoat
sudo docker compose exec database mongodump --out /data/backup
```

### Monitoring

Add CloudWatch alarms (optional enhancement):
- EC2 CPU utilization
- EBS disk space
- S3 bucket size
- Application health checks

## Security Considerations

- ✅ HTTPS enforced (Caddy auto-redirects HTTP)
- ✅ S3 buckets encrypted (AES-256)
- ✅ EBS volumes encrypted
- ✅ No long-lived AWS credentials (OIDC)
- ✅ IMDSv2 enforced on EC2
- ✅ Security groups restrict access
- ✅ SSH disabled by default

**Recommended Enhancements**:
- Enable AWS GuardDuty
- Configure VPC Flow Logs
- Set up AWS WAF on ALB
- Implement S3 bucket policies for VPC-only access
- Enable CloudTrail for audit logging

## Destroying Infrastructure

**Warning**: This will delete all data!

```bash
cd infrastructure
terraform destroy

# Then remove OIDC setup
cd ../oidc-setup
terraform destroy
```

## Support

- **Stoat Chat**: https://github.com/stoatchat
- **Terraform AWS**: https://registry.terraform.io/providers/hashicorp/aws
- **Issues**: Create an issue in this repository

## License

This infrastructure code is provided as-is. Stoat Chat has its own licensing terms - see the [Stoat repository](https://github.com/stoatchat) for details.

## Contributing

Contributions welcome! Please:
1. Fork this repository
2. Create a feature branch
3. Submit a pull request

---

**Built with** ❤️ **using Terraform and GitHub Actions**
