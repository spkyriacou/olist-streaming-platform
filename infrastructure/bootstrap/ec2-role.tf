resource "aws_iam_role" "olist_ec2" {
  name = "olist-dev-ec2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "olist_ec2_ssm" {
  role       = aws_iam_role.olist_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "olist_ec2_source_data" {
  name = "olist-read-source-data"
  role = aws_iam_role.olist_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid      = "ListSourceFiles"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${local.olist_data_bucket_name}"

        Condition = {
          StringLike = {
            "s3:prefix" = [
              "raw/olist",
              "raw/olist/*"
            ]
          }
        }
      },
      {
        Sid      = "ReadSourceFiles"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::${local.olist_data_bucket_name}/raw/olist/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "olist_ec2" {
  name = "olist-dev-ec2"
  role = aws_iam_role.olist_ec2.name
}

output "ec2_instance_profile_name" {
  value = aws_iam_instance_profile.olist_ec2.name
}