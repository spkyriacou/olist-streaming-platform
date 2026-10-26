locals {
  olist_data_bucket_name = "olist-streaming-473c7de2906e4ce024aaeba19f"
}

resource "aws_iam_role_policy" "github_terraform" {
  name = "olist-terraform-deployment"
  role = aws_iam_role.github_terraform.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid      = "ListStateBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.terraform_state.arn

        Condition = {
          StringLike = {
            "s3:prefix" = [
              "olist/dev/*",
              "env:/*"
            ]
          }
        }
      },
      {
        Sid    = "ReadWriteProjectState"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject"]
        Resource = [
          "${aws_s3_bucket.terraform_state.arn}/olist/dev/terraform.tfstate"
        ]
      },
      {
        Sid    = "ManageProjectStateLock"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.terraform_state.arn}/olist/dev/terraform.tfstate.tflock"
        ]
      },
      {
        Sid      = "ReadDataBucketConfiguration"
        Effect   = "Allow"
        Action   = ["s3:Get*", "s3:ListBucket"]
        Resource = "arn:aws:s3:::${local.olist_data_bucket_name}"
      },
      {
        Sid      = "ReadNetworkConfiguration"
        Effect   = "Allow"
        Action   = ["ec2:Describe*"]
        Resource = "*"

        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "eu-west-2"
          }
        }
      },
      {
        Sid    = "ManageNetworkingInLondon"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateRoute",
          "ec2:ReplaceRoute",
          "ec2:DeleteRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:ReplaceRouteTableAssociation",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"

        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "eu-west-2"
          }
        }
      }
    ]
  })
}