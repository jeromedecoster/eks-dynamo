# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table
resource "aws_dynamodb_table" "vote" {
  name           = var.project_name
  read_capacity  = 2
  write_capacity = 2
  # partition key
  hash_key = "name"

  attribute {
    name = "name"
    type = "S"
  }

  lifecycle {
    ignore_changes = [read_capacity, write_capacity]
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table_item
resource "aws_dynamodb_table_item" "item_up" {
  table_name = aws_dynamodb_table.vote.name
  hash_key   = aws_dynamodb_table.vote.hash_key

  item = <<EOF
{
  "name": {"S": "up"},
  "value" : {"N": "0" }
}
EOF

  # ignore updated value (no reset)
  # https://www.terraform.io/language/meta-arguments/lifecycle#ignore_changes
  lifecycle {
    ignore_changes = [item]
  }
}

resource "aws_dynamodb_table_item" "item_down" {
  table_name = aws_dynamodb_table.vote.name
  hash_key   = aws_dynamodb_table.vote.hash_key

  item = <<EOF
{
  "name": {"S": "down"},
  "value" : {"N": "0" }
}
EOF

  lifecycle {
    ignore_changes = [item]
  }
}
