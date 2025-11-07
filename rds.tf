resource "aws_db_subnet_group" "db" {
  name       = "${local.name}-dbsubnets"
  subnet_ids = [for s in aws_subnet.private : s.id]
  tags       = merge(local.common_tags, { Name = "${local.name}-dbsubnets" })
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "RDS SG"
  vpc_id      = aws_vpc.this.id

  # open to VPC for demo; tighten to app SGs in real env
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name}-rds-sg" })
}

# Discover a valid Postgres 16.x version in THIS region
# Discover a valid Postgres version in this region (tries newest first)
data "aws_rds_engine_version" "pg" {
  engine             = "postgres"
  preferred_versions = ["17.6", "17.5", "17.4", "17", "16.4", "16.3", "16.2", "16"]
}

resource "aws_db_parameter_group" "pg" {
  name   = "${local.name}-pg"
  family = data.aws_rds_engine_version.pg.parameter_group_family
  tags   = local.common_tags
}

resource "aws_db_instance" "this" {
  identifier = "${local.name}-pg"
  engine     = "postgres"
  # If var is null/empty => use discovered version
  engine_version = (
    try(length(trim(var.db_engine_version)) > 0, false)
  ) ? var.db_engine_version : data.aws_rds_engine_version.pg.version

  parameter_group_name       = aws_db_parameter_group.pg.name
  instance_class             = var.db_instance_class
  db_subnet_group_name       = aws_db_subnet_group.db.name
  vpc_security_group_ids     = [aws_security_group.rds.id]
  allocated_storage          = var.db_allocated_storage
  storage_type               = "gp3"
  storage_encrypted          = true
  auto_minor_version_upgrade = true
  apply_immediately          = true
  skip_final_snapshot        = true
  publicly_accessible        = false
  multi_az                   = false

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  tags                            = merge(local.common_tags, { Name = "${local.name}-rds" })
}
