resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "github_terraform" {
  name = "olist-github-terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }

      Action = "sts:AssumeRoleWithWebIdentity"

      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:spkyriacou@170625507/olist-streaming-platform@1428494757:ref:refs/heads/main"
        }
      }
    }]
  })
}

output "github_terraform_role_arn" {
  description = "AWS role used by GitHub Actions"
  value       = aws_iam_role.github_terraform.arn
}