resource "aws_s3_bucket" "olist" {
  bucket_prefix = "olist-streaming-"

  tags = {
    Project     = "olist-streaming-platform"
    Environment = "dev"
  }
}

resource "aws_s3_bucket_public_access_block" "olist" {
  bucket = aws_s3_bucket.olist.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "olist_bucket_name" {
  description = "Name of the S3 bucket for the Olist project"
  value       = aws_s3_bucket.olist.id
}