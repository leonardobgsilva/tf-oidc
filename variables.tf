variable "aws_region" {
  description = "AWS region for the ECR repositories."
  type        = string
  default     = "us-east-1"
}

variable "github_owner" {
  description = "GitHub user or organization that owns the repositories allowed to assume the role."
  type        = string
  default     = "leonardobgsilva"
}

variable "github_repositories" {
  description = "GitHub repositories (names only) allowed to assume the CI role."
  type        = list(string)
  default     = ["app-leocinema-backend", "app-leocinema-frontend"]
}

variable "allowed_refs" {
  description = "Git refs allowed to assume the role. Pull requests from forks are never allowed."
  type        = list(string)
  default     = ["refs/heads/main", "refs/heads/oidc"]
}

variable "ecr_repository_names" {
  description = "ECR repositories that receive the application images."
  type        = list(string)
  default     = ["leocinema-backend", "leocinema-frontend"]
}

variable "max_image_count" {
  description = "How many images to keep per ECR repository."
  type        = number
  default     = 10
}

variable "role_name" {
  description = "Name of the IAM role assumed by GitHub Actions."
  type        = string
  default     = "leocinema-gha-ecr-push"
}
