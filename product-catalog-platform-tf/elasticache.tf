
# --------------------------------------------------
# ElastiCache Serverless - Valkey
# --------------------------------------------------

resource "aws_elasticache_serverless_cache" "valkey" {
  name        = "${var.project_name}-valkey"
  engine      = "valkey"
  description = "Product catalog serverless Valkey cache"

  # Place the cache endpoint inside our private VPC
  subnet_ids = aws_subnet.private[*].id

  # Only Lambda is allowed to connect
  security_group_ids = [
    aws_security_group.valkey.id
  ]

  # Keep the maximum capacity bounded for this project
  cache_usage_limits {
    data_storage {
      maximum = 1
      unit    = "GB"
    }

    ecpu_per_second {
      maximum = 1000
    }
  }

  tags = {
    Name        = "${var.project_name}-valkey"
    Environment = "learning"
    Project     = var.project_name
  }
}
