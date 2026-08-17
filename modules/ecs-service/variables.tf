variable "name" {
  description = "Name prefix. Also used as the cluster, service, and container name."
  type        = string
}

variable "region" {
  description = "Region, needed for the awslogs driver configuration."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "Subnets for the ALB. Must span at least two AZs."
  type        = list(string)
}

variable "task_subnet_ids" {
  description = "Subnets for the Fargate tasks. Private in production; public when running without a NAT gateway."
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Required when tasks run in public subnets with no NAT gateway."
  type        = bool
  default     = true
}

variable "container_image" {
  description = "Image URI. A public nginx image is a reasonable placeholder."
  type        = string
  default     = "public.ecr.aws/nginx/nginx:stable"
}

variable "container_port" {
  type    = number
  default = 80
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "task_cpu" {
  description = "Fargate CPU units. 256 = 0.25 vCPU, the cheapest valid size."
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "MiB. Must be a valid pairing with task_cpu; 512 is the minimum for 256 CPU."
  type        = string
  default     = "512"
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "min_capacity" {
  type    = number
  default = 2
}

variable "max_capacity" {
  type    = number
  default = 6
}

variable "cpu_target_value" {
  description = "Average CPU percent to hold."
  type        = number
  default     = 60
}

variable "memory_target_value" {
  type    = number
  default = 75
}

variable "log_retention_days" {
  description = "Never leave this unset. Logs default to infinite retention and bill forever."
  type        = number
  default     = 7
}

variable "enable_container_insights" {
  description = "Extra CloudWatch metrics. Costs money; off by default."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
