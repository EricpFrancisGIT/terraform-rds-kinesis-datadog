resource "aws_s3_bucket" "dlq" {
  bucket        = "${local.name}-dlq-${random_id.rand.hex}"
  force_destroy = true
  tags          = local.common_tags
}

resource "random_id" "rand" { byte_length = 4 }
