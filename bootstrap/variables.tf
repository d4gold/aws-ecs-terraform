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
variable "budget_name" {
  description = "Name of the monthly cost budget. Matches the budget that already exists so it can be imported rather than recreated."
  type        = string
  default     = "aws-ecs-terraform-monthly"
}

variable "budget_limit_usd" {
  description = "Monthly cost budget in USD. Alerts only; AWS does not stop spending at this figure."
  type        = string
  default     = "5"
}

variable "budget_notification_email" {
  description = "Address that receives budget alerts. Set via TF_VAR_budget_notification_email. Deliberately has no default so a personal address stays out of this public repository."
  type        = string
}
