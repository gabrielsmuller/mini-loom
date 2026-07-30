# Minimal private network for Aurora.
#
# Aurora (a relational DB) must live inside a VPC. But because we reach it via
# the RDS Data API (HTTPS) rather than a raw connection, nothing here needs to
# talk to the internet — so there is NO Internet Gateway and NO NAT Gateway.
# It's just a private address space with two subnets for the DB to live in.
#
# Why two subnets in two AZs? Aurora requires its "DB subnet group" to span at
# least two Availability Zones, so AWS can place a standby in another zone for
# durability. They're private (no internet route) by design.

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project}-vpc" }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24" # 10.0.1.0/24, 10.0.2.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "${var.project}-private-${count.index + 1}" }
}

# Groups the subnets into the set Aurora will launch into.
resource "aws_db_subnet_group" "aurora" {
  name       = "${var.project}-aurora"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "${var.project}-aurora" }
}

# The cluster needs a security group even though the Data API doesn't use it.
# We open nothing inbound: the Data API reaches Aurora over AWS's own HTTPS
# service, not through this VPC, so there's nothing to allow in here.
resource "aws_security_group" "aurora" {
  name        = "${var.project}-aurora"
  description = "Aurora cluster SG. No inbound needed; access is via the Data API."
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-aurora" }
}
