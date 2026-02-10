output "stoat_public_ip" {
  description = "Public IP address of the Stoat Chat server"
  value       = aws_eip.stoat.public_ip
}

output "stoat_domain" {
  description = "Domain name for Stoat Chat"
  value       = var.domain_name
}

output "stoat_url" {
  description = "Full URL to access Stoat Chat"
  value       = "https://${var.domain_name}"
}

output "s3_media_bucket" {
  description = "S3 bucket name for media storage"
  value       = aws_s3_bucket.media.id
}

output "s3_media_bucket_arn" {
  description = "S3 bucket ARN for media storage"
  value       = aws_s3_bucket.media.arn
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.stoat.id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.stoat.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "cbains_hosted_zone_id" {
  description = "Hosted Zone ID for aws.cbains.ca"
  value       = aws_route53_zone.cbains.zone_id
}

output "cbains_hosted_zone_name_servers" {
  description = "Name servers for aws.cbains.ca (configure these in your domain registrar)"
  value       = aws_route53_zone.cbains.name_servers
}

output "ecr_repositories" {
  description = "ECR repository URLs for Stoat components"
  value = {
    for name, repo in aws_ecr_repository.stoat_components : name => repo.repository_url
  }
}



output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = var.aws_region
}

output "stoat_cbains_domain" {
  description = "Stoat domain in the cbains zone"
  value       = "stoat.aws.cbains.ca"
}
