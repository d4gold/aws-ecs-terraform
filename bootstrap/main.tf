# ---------------------------------------------------------------------------
# Bootstrap: the chicken-and-egg layer.
#
# This creates the S3 bucket that holds remote state for everything else,
# plus the GitHub OIDC provider and CI role. It runs with LOCAL state,
# committed nowhere, because it has to exist before remote state can.
#
# Run this once. Then every other config uses the S3 backend.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.10" # 1.10+ required for S3 native state locking
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = "aws-ecs-terraform"
      ManagedBy = "terraform"
      Layer     = "bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  state_bucket = "${var.name_prefix}-tfstate-${data.aws_caller_identity.current.account_id}"
}

# ---------------------------------------------------------------------------
# State bucket.
#
# Versioning is the important one: it is the only way back from a corrupted
# or accidentally-deleted state file. Encryption and public access blocking
# are table stakes -- state contains secrets in plaintext.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket

  # Non-production: allow terraform destroy to clean up.
  # In production this is true and the bucket is never destroyed.
  force_destroy = var.force_destroy_state_bucket
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Deny any request that is not TLS. Cheap, and the kind of control a
# compliance reviewer looks for by name.
data "aws_iam_policy_document" "state_bucket" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_bucket.json
}

# Expire old state versions so the bucket does not grow without bound.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC.
#
# Instead of storing an AWS access key in GitHub secrets, GitHub presents a short-lived OIDC token and
# AWS exchanges it for temporary credentials. No long-lived keys exist, so
# there is nothing to leak or rotate.
#
# The trust policy is scoped to one repo. Leaving the sub condition as
# "repo:*" is the classic misconfiguration -- it lets ANY GitHub repo in the
# world assume the role.
# ---------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  count = var.enable_github_oidc ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_assume" {
  count = var.enable_github_oidc ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Scoped to this repository only. Narrow further with
    # "repo:owner/name:ref:refs/heads/main" to restrict to one branch.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  count = var.enable_github_oidc ? 1 : 0

  name               = "${var.name_prefix}-github-actions"
  description        = "Assumed by GitHub Actions via OIDC. No static credentials."
  assume_role_policy = data.aws_iam_policy_document.github_assume[0].json

  # Cap the session at one hour regardless of what the workflow requests.
  max_session_duration = 3600
}

# Read-only for plan. Attach a broader policy only if you want CI to apply.
resource "aws_iam_role_policy_attachment" "github_readonly" {
  count = var.enable_github_oidc ? 1 : 0

  role       = aws_iam_role.github_actions[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Plan needs to read state and write the lock file.
data "aws_iam_policy_document" "github_state" {
  count = var.enable_github_oidc ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketVersioning"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }
}

resource "aws_iam_role_policy" "github_state" {
  count = var.enable_github_oidc ? 1 : 0

  name   = "terraform-state-access"
  role   = aws_iam_role.github_actions[0].id
  policy = data.aws_iam_policy_document.github_state[0].json
}
