resource "aws_iam_role_policy" "github_migrations" {
  name = "olist-database-migrations"
  role = aws_iam_role.github_terraform.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid      = "UseShellCommandDocument"
        Effect   = "Allow"
        Action   = ["ssm:SendCommand"]
        Resource = "arn:aws:ssm:eu-west-2::document/AWS-RunShellScript"
      },
      {
        Sid      = "RunCommandsOnOlistServer"
        Effect   = "Allow"
        Action   = ["ssm:SendCommand"]
        Resource = "arn:aws:ec2:eu-west-2:652546415579:instance/*"

        Condition = {
          StringEquals = {
            "ssm:resourceTag/Project"     = "olist-streaming-platform"
            "ssm:resourceTag/Environment" = "dev"
            "ssm:resourceTag/Name"        = "olist-dev"
          }
        }
      },
      {
        Sid      = "ReadCommandResults"
        Effect   = "Allow"
        Action   = ["ssm:GetCommandInvocation"]
        Resource = "*"
      }
    ]
  })
}