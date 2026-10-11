output "role_arn" {
  description = "Set this as the AWS_ROLE_ARN secret (or hard-code it) in the GitHub workflows."
  value       = aws_iam_role.gha_ecr_push.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC identity provider."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "ecr_repository_urls" {
  description = "Registry URLs for docker push."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "allowed_subjects" {
  description = "OIDC subjects that can assume the role."
  value       = local.oidc_subjects
}
