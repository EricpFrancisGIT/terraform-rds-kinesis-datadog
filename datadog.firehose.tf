#############################
# Datadog Firehose pipeline #
#############################

# Who am I (for IAM policy scoping, optional)
data "aws_caller_identity" "current" {}

############################################
# S3 bucket for Firehose backup (required) #
############################################
resource "aws_s3_bucket" "firehose_backup" {
  bucket = "${local.name}-firehose-backup"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "firehose_backup" {
  bucket = aws_s3_bucket.firehose_backup.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "firehose_backup" {
  bucket = aws_s3_bucket.firehose_backup.id
  rule {
    id     = "expire-30d"
    status = "Enabled"
    expiration { days = 30 }
  }
}

##############################################
# Lambda transform: CWL JSON -> Datadog NDJSON
##############################################
data "archive_file" "firehose_transform_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/firehose_transform.py"
  output_path = "${path.module}/lambda/firehose_transform.zip"
}

resource "aws_iam_role" "firehose_transform_lambda_role" {
  name = "${local.name}-firehose-transform"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect : "Allow",
      Principal : { Service : "lambda.amazonaws.com" },
      Action : "sts:AssumeRole"
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "firehose_transform_basic" {
  role       = aws_iam_role.firehose_transform_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "firehose_transform" {
  function_name = "${local.name}-firehose-transform"
  role          = aws_iam_role.firehose_transform_lambda_role.arn
  runtime       = "python3.11"
  handler       = "firehose_transform.handler"
  filename      = data.archive_file.firehose_transform_zip.output_path
  memory_size   = 256
  timeout       = 60
  environment {
    variables = {
      DD_SOURCE  = "rds-postgres"
      DD_SERVICE = local.name
    }
  }
  tags = local.common_tags
}

###################################
# Firehose role (S3 + Lambda invoke)
###################################
resource "aws_iam_role" "firehose_role" {
  name = "${local.name}-firehose-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect : "Allow",
      Principal : { Service : "firehose.amazonaws.com" },
      Action : "sts:AssumeRole"
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "firehose_role" {
  name = "${local.name}-firehose-inline"
  role = aws_iam_role.firehose_role.id
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "s3:AbortMultipartUpload", "s3:GetBucketLocation", "s3:GetObject",
          "s3:ListBucket", "s3:ListBucketMultipartUploads", "s3:PutObject"
        ],
        Resource : [
          aws_s3_bucket.firehose_backup.arn,
          "${aws_s3_bucket.firehose_backup.arn}/*"
        ]
      },
      {
        Effect : "Allow",
        Action : ["lambda:InvokeFunction", "lambda:GetFunctionConfiguration"],
        Resource : aws_lambda_function.firehose_transform.arn
      },
      {
        Effect : "Allow",
        Action : ["logs:PutLogEvents"],
        Resource : "*"
      }
    ]
  })
}

##########################################################
# Firehose delivery stream -> Datadog HTTP logs intake
##########################################################


resource "aws_kinesis_firehose_delivery_stream" "dd_logs" {
  name        = "${local.name}-dd-logs"
  destination = "http_endpoint"

  http_endpoint_configuration {
    name               = "datadog"
    url                = "https://http-intake.logs.${var.datadog_site}/api/v2/logs"
    access_key         = var.datadog_api_key # Datadog accepts Firehose's access_key as API key
    buffering_interval = 60
    buffering_size     = 4
    retry_duration     = 300
    s3_backup_mode     = "FailedDataOnly"

    role_arn = aws_iam_role.firehose_role.arn


    request_configuration {
      content_encoding = "GZIP"
      # optional: add static attributes on every line
      # common_attributes = [
      #   { name = "service", value = local.name },
      #   { name = "ddsource", value = "rds-postgres" }
      # ]
    }

    processing_configuration {
      enabled = true
      processors {
        type = "Lambda"
        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = aws_lambda_function.firehose_transform.arn
        }
      }
    }

    s3_configuration {
      role_arn           = aws_iam_role.firehose_role.arn
      bucket_arn         = aws_s3_bucket.firehose_backup.arn
      buffering_interval = 300
      buffering_size     = 5
      compression_format = "GZIP"

      cloudwatch_logging_options {
        enabled         = true
        log_group_name  = "/aws/kinesisfirehose/${local.name}-dd-logs"
        log_stream_name = "S3Backup"
      }
    }
  }

  tags = local.common_tags
}

######################################################################
# CloudWatch Logs -> Subscription to Firehose (RDS postgresql log group)
######################################################################
resource "aws_iam_role" "logs_to_firehose" {
  name = "${local.name}-logs-to-firehose"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect : "Allow",
      Principal : { Service : "logs.${var.aws_region}.amazonaws.com" },
      Action : "sts:AssumeRole"
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "logs_to_firehose" {
  name = "${local.name}-logs-to-firehose"
  role = aws_iam_role.logs_to_firehose.id
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [{
      Effect : "Allow",
      Action : ["firehose:PutRecord", "firehose:PutRecordBatch", "firehose:DescribeDeliveryStream"],
      Resource : aws_kinesis_firehose_delivery_stream.dd_logs.arn
    }]
  })
}

resource "aws_cloudwatch_log_subscription_filter" "rds_to_firehose" {
  name            = "${local.name}-rds-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.rds_pg.name
  filter_pattern  = "" # all events
  destination_arn = aws_kinesis_firehose_delivery_stream.dd_logs.arn
  role_arn        = aws_iam_role.logs_to_firehose.arn

  depends_on = [
    aws_db_instance.this,
    aws_cloudwatch_log_group.rds_pg,
    aws_kinesis_firehose_delivery_stream.dd_logs
  ]
}
