resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = var.tags
}

# create versioning for the bucket
resource "aws_s3_bucket_versioning" "this" {
  # create this resource only if var.versioning is not empty
  count = var.enable_versioning ? 1 : 0

  bucket = aws_s3_bucket.this.id

  # enable versioning
  versioning_configuration {
    status = "Enabled"
  }
}

# Create a server-side encryption configuration for the bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  # create this resource only if var.sse_algorithm is not empty
  count = var.sse_algorithm != "" ? 1 : 0

  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.sse_algorithm == "aws:kms" ? aws_kms_key.custom_s3_kms_key[0].key_id : null
      sse_algorithm     = var.sse_algorithm
    }
  }
}

# block public access
resource "aws_s3_bucket_public_access_block" "this" {

  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.block_public_access
  block_public_policy     = var.block_public_access
  ignore_public_acls      = var.block_public_access
  restrict_public_buckets = var.block_public_access
}


resource "aws_s3_bucket_website_configuration" "this" {
  count  = var.enable_website_configuration ? 1 : 0
  bucket = aws_s3_bucket.this.id

  index_document {
    suffix = var.website_index_document
  }

  error_document {
    key = var.website_error_document
  }
}

resource "aws_s3_bucket_policy" "website_bucket_policy" {
  count  = var.enable_website_configuration ? 1 : 0
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.website_bucket_policy[0].json
}

data "aws_iam_policy_document" "website_bucket_policy" {
  count = var.enable_website_configuration ? 1 : 0
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

  }
}

resource "aws_s3_bucket_policy" "allow_access" {
  count  = var.bucket_policy != "" ? 1 : 0
  bucket = aws_s3_bucket.this.id
  policy = var.bucket_policy
}


resource "aws_kms_key" "custom_s3_kms_key" {
  count               = var.sse_algorithm == "aws:kms" ? 1 : 0
  description         = "Custom KMS key for s3 bucket encryption"
  enable_key_rotation = true
}

resource "aws_kms_alias" "a" {
  count         = var.sse_algorithm == "aws:kms" ? 1 : 0
  name          = "alias/s3-${replace(aws_s3_bucket.this.bucket, ".", "-")}"
  target_key_id = aws_kms_key.custom_s3_kms_key[0].key_id
}

data "aws_caller_identity" "current" {}









