variable "name" {
  description = "Name prefix for all database resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC in which to create the database and its security group."
  type        = string
}

variable "private_subnet_ids" {
  description = "Must span at least two AZs or Multi-AZ creation fails."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups permitted to reach the database, keyed by a stable name. Usually the ECS task SG."
  type        = map(string)
  default     = {}
}

variable "engine_version" {
  description = "PostgreSQL engine version. Must match the major version in parameter_group_family."
  type        = string
  default     = "16.4"
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
  description = "Initial storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper bound for storage autoscaling. Set above allocated_storage to enable it."
  type        = number
  default     = 50
}

variable "database_name" {
  description = "Name of the initial database created on the instance."
  type        = string
  default     = "appdb"
}

variable "master_username" {
  description = "Master user name. The password is generated and stored in Secrets Manager."
  type        = string
  default     = "dbadmin"
}

variable "port" {
  description = "Port the database listens on."
  type        = number
  default     = 5432
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
  description = "Blocks accidental deletion. True in production."
  type        = bool
  default     = false
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
  description = "Create the CloudWatch alarms for free storage and CPU."
  type        = bool
  default     = true
}

variable "free_storage_alarm_bytes" {
  description = "Alarm threshold in bytes. Default is 2 GiB."
  type        = number
  default     = 2147483648
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
