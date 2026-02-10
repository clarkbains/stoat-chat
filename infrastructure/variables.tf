variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
}

variable "domain_name" {
  description = "Domain name for Stoat Chat (must exist in Route53)"
  type        = string
}

variable "zone" {
  description = "Route53 hosted zone name (e.g. example.com.)"
  type        = string
  
}

variable "instance_type" {
  description = "EC2 instance type (t4g.small recommended for ARM Graviton)"
  type        = string
  default     = "t4g.small"
}

variable "root_volume_size" {
  description = "Size of root EBS volume in GB"
  type        = number
  default     = 30
}

variable "s3_media_bucket_name" {
  description = "Name for S3 media bucket (leave empty for auto-generated name)"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH to instance (leave empty to disable SSH)"
  type        = string
  default     = ""
}

variable "stoat_version" {
  description = "Stoat Chat version/tag to deploy"
  type        = string
  default     = "latest"
}

variable "key_pair_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
  default     = ""
}
