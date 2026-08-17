variable "name" {
  description = "Name prefix for all VPC resources."
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to span. Two is the minimum for an ALB and for RDS Multi-AZ."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "az_count must be at least 2: an ALB requires subnets in two availability zones, and RDS Multi-AZ needs a subnet group spanning two."
  }
}

variable "enable_nat_gateway" {
  description = "Create a NAT gateway for private subnet egress. Costs ~$32/month if left running. Default off."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
