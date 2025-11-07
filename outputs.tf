output "datadog_forwarder_name" {
  value = data.aws_lambda_function.dd_forwarder.function_name
}

output "datadog_forwarder_arn" {
  value = data.aws_lambda_function.dd_forwarder.arn
}

output "datadog_forwarder_region" {
  value       = data.aws_lambda_function.dd_forwarder.arn != null ? regex("^arn:aws:lambda:([a-z0-9-]+):", data.aws_lambda_function.dd_forwarder.arn)[0] : null
  description = "Region where the forwarder Lambda is deployed."
}

output "datadog_forwarder_stack_id" {
  value       = aws_cloudformation_stack.datadog_forwarder.id
  description = "CloudFormation stack ID for the Datadog forwarder."
}

output "datadog_forwarder_stack_outputs" {
  value       = aws_cloudformation_stack.datadog_forwarder.outputs
  description = "Raw CloudFormation outputs map (may be empty depending on template version)."
}
