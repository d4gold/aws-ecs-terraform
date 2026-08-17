variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  description = "Must span at least two AZs or Multi-AZ creation fails."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups permitted to reach the database. Usually the ECS task SG."
  type        = list(string)
  default     = []
}

variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "parameter_group_family" {
  description = "Must match the major version of engine_version."
  type        = string
  default     = "postgres16"
}

variable "instance_class" {
  description = "db.t4g.micro is the cheapest current-gen option and free-tier eligible on new accounts."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  description = "Upper bound for storage autoscaling. Set above allocated_storage to enable it."
  type        = number
  default     = 50
}

variable "database_name" {
  type    = string
  default = "appdb"
}

variable "master_username" {
  type    = string
  default = "dbadmin"
}

variable "port" {
  type    = number
  default = 5432
}

variable "multi_az" {
  description = "Roughly doubles cost. False in dev, true in production."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Days. Zero disables automated backups and point-in-time recovery."
  type        = number
  default     = 7
}

variable "performance_insights_enabled" {
  description = "Free for 7 days of retention on supported classes."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  description = "True only in a throwaway account. Always false in production."
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "True in dev so changes are not deferred to the maintenance window."
  type        = bool
  default     = true
}

variable "create_alarms" {
  type    = bool
  default = true
}

variable "free_storage_alarm_bytes" {
  description = "Alarm threshold in bytes. Default is 2 GiB."
  type        = number
  default     = 2147483648
}

variable "tags" {
  type    = map(string)
  default = {}
}
