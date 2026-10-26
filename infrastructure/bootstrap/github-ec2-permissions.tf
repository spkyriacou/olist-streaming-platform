resource "aws_iam_role_policy" "github_ec2" {
  name = "olist-ec2-deployment"
  role = aws_iam_role.github_terraform.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ManageEC2InLondon"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:ModifyInstanceAttribute",
          "ec2:ModifyInstanceMetadataOptions",
          "ec2:ModifyVolume",
          "ec2:AssociateIamInstanceProfile",
          "ec2:DisassociateIamInstanceProfile",
          "ec2:ReplaceIamInstanceProfileAssociation"
        ]
        Resource = "*"

        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "eu-west-2"
          }
        }
      },
      {
        Sid      = "ReadEC2InstanceProfile"
        Effect   = "Allow"
        Action   = ["iam:GetInstanceProfile"]
        Resource = aws_iam_instance_profile.olist_ec2.arn
      },
      {
        Sid      = "PassOnlyOlistServerRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.olist_ec2.arn

        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ec2.amazonaws.com"
          }
        }
      }
    ]
  })
}