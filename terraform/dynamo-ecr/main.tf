provider "aws" {
  region = var.region
}

resource "local_file" "aws_account_id" {
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity#account_id
  content = data.aws_caller_identity.current.account_id

  # target the $PROJECT_DIR
  filename = "${path.module}/../../.env_AWS_ACCOUNT_ID"
}

# https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file
resource "local_file" "repository_url" {
  content = aws_ecr_repository.vote.repository_url

  filename = "${path.module}/../../.env_REPOSITORY_URL"
}

resource "local_file" "aws_access_key_id" {
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key#id
  content = aws_iam_access_key.user_key.id

  filename = "${path.module}/../../.env_AWS_ACCESS_KEY_ID"
}

resource "local_file" "aws_secret_access_key" {
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key#secret
  content = aws_iam_access_key.user_key.secret

  filename = "${path.module}/../../.env_AWS_SECRET_ACCESS_KEY"
}