terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  # Every resource gets these automatically. Makes cost tracking and
  # "did I actually destroy everything?" trivial.
  default_tags {
    tags = {
      Project   = "aws-ecs-terraform"
      ManagedBy = "terraform"
      Owner     = "denton"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "name" {
  type    = string
  default = "app"
}

module "vpc" {
  source = "../../modules/vpc"

  name       = var.name
  cidr_block = "10.20.0.0/16"
  az_count   = 2

  # Leave false unless private egress is required.
  enable_nat_gateway = false
}

module "app" {
  source = "../../modules/ecs-service"

  name   = var.name
  region = var.region

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids

  # Tasks run in PUBLIC subnets here because enable_nat_gateway is false.
  # With NAT on, switch these two lines to private subnets and false.
  task_subnet_ids  = module.vpc.public_subnet_ids
  assign_public_ip = true

  container_image = "public.ecr.aws/nginx/nginx:stable"
  container_port  = 80

  desired_count = 2
  min_capacity  = 2
  max_capacity  = 6
}

module "db" {
  source = "../../modules/rds"

  name               = var.name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # This is the SG chain closing: only the Fargate tasks can reach Postgres.
  allowed_security_group_ids = [module.app.task_security_group_id]

  instance_class = "db.t4g.micro"
  multi_az       = false # true for failover coverage; roughly doubles cost
}

output "db_endpoint" {
  value = module.db.endpoint
}

output "db_secret_arn" {
  description = "Read the master credentials from here, never from state."
  value       = module.db.secret_arn
}

output "alb_url" {
  description = "Open this once apply finishes. Takes ~60s for targets to go healthy."
  value       = "http://${module.app.alb_dns_name}"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}
