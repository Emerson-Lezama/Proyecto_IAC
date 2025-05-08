resource "aws_s3_bucket" "web_app" {
  bucket = "certificates-web-app-${random_id.bucket_suffix.hex}"
  
  tags = {
    Environment = "production"
    Project     = "certificates-system"
  }
}

resource "aws_s3_bucket_public_access_block" "web_app_block" {
  bucket = aws_s3_bucket.web_app.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "web_app" {
  bucket = aws_s3_bucket.web_app.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "web_app_encryption" {
  bucket = aws_s3_bucket.web_app.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_cloudfront_origin_access_identity" "s3_oai" {
  comment = "Identity para acceder al bucket S3 desde CloudFront"
}

resource "aws_s3_bucket_policy" "web_app_policy" {
  bucket = aws_s3_bucket.web_app.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.s3_oai.iam_arn]
    }
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.web_app.arn,
      "${aws_s3_bucket.web_app.arn}/*"
    ]
  }
}