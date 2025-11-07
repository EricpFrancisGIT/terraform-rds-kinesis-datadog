variable "project_name" {
  type    = string
  default = "rds-kinesis-datadog"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# VPC
variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

# RDS
variable "db_engine" {
  type    = string
  default = "postgres"
}

variable "db_engine_version" {
  type    = string
  default = "16.3"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "appuser"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

# Datadog
variable "datadog_site" {
  type    = string
  default = "datadoghq.com" # or datadoghq.eu, us3.datadoghq.com, us5.datadoghq.com
}

variable "datadog_api_key" {
  type      = string
  sensitive = true
}

# Kinesis
variable "kinesis_shard_count" {
  type    = number
  default = 1
}

# Tags
variable "tags" {
  type    = map(string)
  default = { Project = "rds-kinesis-datadog", Owner = "platform" }
}
