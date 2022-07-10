output "project_name" {
  value = var.project_name
}

output "region" {
  value = var.region
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table#arn
output "dynamodb_vote_arn" {
  value = aws_dynamodb_table.vote.arn
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table#id
# output "dynamodb_vote_id" {
#   value = aws_dynamodb_table.vote.id
# }

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository#repository_url
output "ecr_repository_url" {
  value = aws_ecr_repository.vote.repository_url
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository#arn
# output "ecr_registry_arn" {
#   value = aws_ecr_repository.vote.arn
# }

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity#account_id
output "account_id" {
  value = data.aws_caller_identity.current.account_id
}