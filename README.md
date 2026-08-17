# AWS container platform — Terraform

A containerised web stack on AWS, defined end to end in Terraform: a
two-AZ VPC, an ECS Fargate service behind an Application Load Balancer, and
a PostgreSQL database in private subnets.

State lives in S3 with native locking. CI authenticates to AWS through
GitHub Actions OIDC, so no long-lived AWS keys exist anywhere.

```
internet ──▶ ALB (public subnets) ──▶ Fargate tasks (awsvpc) ──▶ RDS (private subnets)
                  alb-sg          ──▶      task-sg          ──▶      rds-sg
```

Each security group allows traffic only from the one in front of it, by
security group ID rather than CIDR.

## Layout

```
bootstrap/       S3 state bucket + GitHub OIDC provider and CI role
modules/
  vpc/           subnets, routing, optional NAT
  ecs-service/   Fargate service, ALB, target group, IAM, autoscaling
  rds/           PostgreSQL, subnet group, Secrets Manager credentials
envs/dev/        wires the modules together
.github/         fmt, validate and tflint on every push; plan on PRs
```

## Usage

`bootstrap/` runs once, with local state, because it creates the bucket that
every other configuration uses as a backend. It provisions IAM resources, so
it needs a role with IAM write access.

```bash
cd bootstrap
terraform init
terraform apply          # outputs the state bucket name
```

Copy the emitted bucket name into `envs/dev/backend.tf`, then:

```bash
cd ../envs/dev
terraform init
terraform plan
terraform apply
```

`terraform destroy` when the environment is no longer needed — see cost below.

## Design notes

- **Two AZs.** An ALB requires subnets in at least two, and single-AZ is not
  fault tolerance.
- **Public subnets hold only the ALB and NAT.** Nothing with data in it.
- **Private subnets hold the tasks and the database.** RDS has no route to
  the internet at all — no public IP, no NAT route.
- **`cidrsubnet(cidr, 8, i)`** carves /24s from the /16 deterministically, so
  adding an AZ does not renumber existing subnets. Private ranges are offset
  by 100 so the two families cannot collide as the AZ count grows.
- **Security groups reference each other by ID**, not by CIDR, so the rules
  survive the ALB changing addresses.
- **Split task and execution roles.** The execution role lets the ECS agent
  pull images and write logs; the task role is what application code assumes.
  Conflating them hands the application ECR credentials it should not have.
- **Database credentials are generated and stored in Secrets Manager**, never
  written as a literal and never passed in as a plaintext variable.
- **NAT is optional.** It is frequently the largest line item in a small
  account, and VPC endpoints for ECR, S3 and CloudWatch Logs can replace it
  for Fargate workloads.

## Cost

Approximate on-demand cost while running, us-east-1:

| Resource | Cost |
|---|---|
| VPC, subnets, route tables, IGW, security groups | free |
| NAT gateway | ~$0.045/hr + data — off by default |
| Application Load Balancer | ~$0.0225/hr |
| Fargate task (0.25 vCPU / 0.5 GB) | ~$0.012/hr |
| RDS db.t4g.micro, single-AZ | ~$0.016/hr |

Roughly **$0.05/hr** with NAT off, closer to $0.10/hr with it on.

Keeping that predictable:

1. Destroy the environment when it is not in use.
2. Leave `enable_nat_gateway = false` unless private egress is required.
3. Set a zero-spend AWS Budgets alert.
4. After a failed destroy, check for orphans that still bill: unattached
   EIPs, ENIs, NAT gateways and RDS snapshots.

## CI

`.github/workflows/terraform.yml` runs `fmt`, `validate` and `tflint` on
every push. The plan job is gated on an `AWS_ROLE_ARN` repository variable;
set it to the role ARN emitted by `bootstrap/` to enable planning against
the real account. Authentication is OIDC — the workflow holds no secrets.
