data "aws_caller_identity" "current" {}

locals {
  # One "sub" claim per repository and per allowed ref, for example:
  # repo:leonardobgsilva/app-leocinema-backend:ref:refs/heads/main
  oidc_subjects = flatten([
    for repo in var.github_repositories : [
      for ref in var.allowed_refs :
      "repo:${var.github_owner}/${repo}:ref:${ref}"
    ]
  ])
}

# ------------------------------------------------------------
# 1. GitHub OIDC identity provider
# ------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # AWS validates the GitHub certificate chain itself; the thumbprints
  # below are the ones GitHub publishes and are kept for compatibility.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# ------------------------------------------------------------
# 2. ECR repositories: immutable tags, scan on push, keep last N
# ------------------------------------------------------------
resource "aws_ecr_repository" "this" {
  for_each = toset(var.ecr_repository_names)

  name                 = each.value
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last ${var.max_image_count} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.max_image_count
      }
      action = { type = "expire" }
    }]
  })
}

# ------------------------------------------------------------
# 3. IAM role assumed by GitHub Actions (no static keys)
# ------------------------------------------------------------
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.oidc_subjects
    }
  }
}

resource "aws_iam_role" "gha_ecr_push" {
  name                 = var.role_name
  description          = "GitHub Actions: push images to the LeoCinema ECR repositories"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "ecr_push" {
  # The login token is not tied to a repository, so it needs "*".
  statement {
    sid       = "EcrLogin"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Push and read-back access, scoped to the two repositories only.
  statement {
    sid    = "EcrPushToLeocinemaRepos"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [for r in aws_ecr_repository.this : r.arn]
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push-leocinema"
  role   = aws_iam_role.gha_ecr_push.id
  policy = data.aws_iam_policy_document.ecr_push.json
}
