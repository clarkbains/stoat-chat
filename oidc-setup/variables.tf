variable "aws_region" {
  description = "AWS region for the OIDC setup and state backend"
  type        = string
  default     = "us-east-1"
}

variable "github_org" {
  description = "GitHub organization or username"
  default = "clarkbains"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  default = "stoat-chat"
  type        = string
}

variable "state_bucket_name" {
  description = "Name for the Terraform state S3 bucket (leave empty for auto-generated name)"
  type        = string
  default     = ""
}

variable "lock_table_name" {
  description = "Name for the DynamoDB lock table"
  type        = string
  default     = "stoat-terraform-locks"
}
