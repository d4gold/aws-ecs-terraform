variable "region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  type    = string
  default = "d4gold"
}

variable "github_repo" {
  description = "owner/repo that CI runs from"
  type        = string
  default     = "d4gold/aws-ecs-terraform"
}

variable "enable_github_oidc" {
  type    = bool
  default = true
}

variable "force_destroy_state_bucket" {
  description = "True only outside production. Never true in production."
  type        = bool
  default     = true
}
