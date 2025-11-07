##############################################
# Datadog Log Forwarder via CloudFormation  #
##############################################

# If your default provider is NOT the region you want the forwarder in,
# pin an alias. Delete this block if not needed.
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

locals {
  dd_forwarder_function_name = "${local.name}-datadog-forwarder"
}


# Optional: who am I (for boundaries, tags, etc.)
# data "aws_caller_identity" "current" {}

# --- Option A: Plain API key (simplest) ---
resource "aws_cloudformation_stack" "datadog_forwarder" {
  # Use the alias if you want to force us-east-1 for the stack; otherwise remove 'provider'
  provider     = aws.use1
  name         = local.dd_forwarder_function_name
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_AUTO_EXPAND"]

  # Official Datadog forwarder template (latest published)
  template_url = "https://datadog-cloudformation-template.s3.amazonaws.com/aws/forwarder/latest.yaml"

  parameters = {
    DdApiKey     = var.datadog_api_key              # required
    DdSite       = var.datadog_site                 # required, e.g. datadoghq.com, us3.datadoghq.com, datadoghq.eu, ddog-gov.com
    FunctionName = local.dd_forwarder_function_name # Optional examples you can uncomment as needed:
    # FunctionName         = "${local.name}-datadog-forwarder"
    # DdTags               = "env:${var.environment},service:${local.name}"
    # LogRetentionInDays   = "14"
    # MemorySize           = "256"
    # ReservedConcurrency  = "5"
    # PythonVersion        = "3.11"
  }

  tags = local.common_tags
}

# --- Option B: Secrets Manager (preferred for prod) ---
# If you store the Datadog API key in Secrets Manager, pass its ARN instead.
# Due to a historical CloudFormation/Terraform quirk, many teams still include
# a dummy DdApiKey and then ignore changes to it. See linked issue.
# resource "aws_cloudformation_stack" "datadog_forwarder" {
#   provider     = aws.use1
#   name         = "${local.name}-datadog-forwarder"
#   capabilities = ["CAPABILITY_IAM", "CAPABILITY_AUTO_EXPAND"]
#   template_url = "https://datadog-cloudformation-template.s3.amazonaws.com/aws/forwarder/latest.yaml"
#
#   parameters = {
#     DdApiKey          = "unused"
#     DdApiKeySecretArn = aws_secretsmanager_secret_version.dd_api_key.arn
#     DdSite            = var.datadog_site
#     # FunctionName    = "${local.name}-datadog-forwarder"
#   }
#
#   # Ignore CFN's NoEcho/diff churn on DdApiKey (Terraform provider nuance)
#   lifecycle {
#     ignore_changes = [ parameters["DdApiKey"] ]
#   }
#
#   tags = local.common_tags
# }
