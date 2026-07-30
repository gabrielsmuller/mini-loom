# Aurora Serverless v2 (PostgreSQL) — the scale-to-zero database.
#
# Two resources: the CLUSTER (the database itself, storage, config) and one
# INSTANCE (the compute that runs it). Serverless v2 sizes that compute in
# "ACUs" (Aurora Capacity Units) and can scale it all the way to 0 when idle.

resource "aws_rds_cluster" "this" {
  cluster_identifier = "${var.project}-db"

  engine         = "aurora-postgresql"
  engine_mode    = "provisioned" # Serverless v2 runs in "provisioned" mode + the scaling block below
  engine_version = "16.6"        # must be a version that supports scale-to-zero; verify on `plan`

  database_name = "miniloom"

  # --- Credentials in Secrets Manager, managed by RDS ---
  # Instead of inventing a password and storing it ourselves, we let RDS create
  # AND rotate the master password, keeping it in Secrets Manager automatically.
  # The Data API authenticates using this secret.
  master_username             = "postgres"
  manage_master_user_password = true

  # --- Networking (the minimal private VPC from vpc.tf) ---
  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  # --- The Data API: an HTTPS door into the cluster (our no-NAT choice) ---
  enable_http_endpoint = true

  # --- Scale to zero ---
  serverlessv2_scaling_configuration {
    min_capacity             = 0   # pause to 0 ACUs when idle → ~$0
    max_capacity             = 1   # small ceiling; plenty for a portfolio
    seconds_until_auto_pause = 300 # idle 5 min → pause
  }

  # Portfolio convenience: allow a clean `terraform destroy` with no leftover snapshot.
  skip_final_snapshot = true
}

# The compute node. "db.serverless" is what makes it Serverless v2 (auto-sized
# by the scaling config above) rather than a fixed-size instance.
resource "aws_rds_cluster_instance" "this" {
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version
}
