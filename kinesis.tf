resource "aws_kinesis_stream" "rds_logs" {
  name             = "${local.name}-rds-logs"
  shard_count      = var.kinesis_shard_count
  retention_period = 24
  stream_mode_details { stream_mode = "PROVISIONED" }
  tags = local.common_tags
}

# Allow CloudWatch Logs to PutRecords into the stream
resource "aws_iam_role" "cwlogs_to_kinesis_role" {
  name               = "${local.name}-cwlogs-to-kinesis"
  assume_role_policy = data.aws_iam_policy_document.cwlogs_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "cwlogs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "cwlogs_to_kinesis_policy" {
  name   = "${local.name}-cwlogs-to-kinesis"
  policy = data.aws_iam_policy_document.cwlogs_to_kinesis.json
}

data "aws_iam_policy_document" "cwlogs_to_kinesis" {
  statement {
    effect    = "Allow"
    actions   = ["kinesis:PutRecord", "kinesis:PutRecords", "kinesis:DescribeStream"]
    resources = [aws_kinesis_stream.rds_logs.arn]
  }
}

resource "aws_iam_role_policy_attachment" "cwlogs_to_kinesis_attach" {
  role       = aws_iam_role.cwlogs_to_kinesis_role.name
  policy_arn = aws_iam_policy.cwlogs_to_kinesis_policy.arn
}

# Subscription filter: RDS log group → Kinesis stream
resource "aws_cloudwatch_log_subscription_filter" "rds_to_kinesis" {
  name            = "${local.name}-rds-to-kinesis"
  log_group_name  = aws_cloudwatch_log_group.rds_pg.name
  filter_pattern  = "" # all events; refine if needed
  destination_arn = aws_kinesis_stream.rds_logs.arn
  role_arn        = aws_iam_role.cwlogs_to_kinesis_role.arn
}

# rds.tf (or a shared logs.tf, same root module)
resource "aws_cloudwatch_log_group" "rds_pg" {
  name              = "/aws/rds/instance/${aws_db_instance.this.id}/postgresql"
  retention_in_days = 14
  tags              = local.common_tags
}
