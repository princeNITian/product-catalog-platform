
variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project resource naming prefix"
  type        = string
  default     = "product-catalog"
}

variable "vpc_cidr" {
  description = "CIDR range for the application VPC"
  type        = string
  default     = "10.20.0.0/16"
}