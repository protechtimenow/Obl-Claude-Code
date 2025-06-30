# Obl Claude Code - Infrastructure as Code for Automation Framework
# Advanced Terraform configuration for enterprise automation infrastructure

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Local variables for configuration
locals {
  project_name = "obl-claude-code"
  environment  = var.environment
  region      = var.aws_region
  
  common_tags = {
    Project             = local.project_name
    Environment         = local.environment
    ManagedBy          = "terraform"
    AutomationManaged  = "true"
    CreatedBy          = "automation-framework"
    LastModified       = timestamp()
  }
  
  automation_config = {
    min_capacity = var.environment == "production" ? 3 : 1
    max_capacity = var.environment == "production" ? 10 : 3
    desired_capacity = var.environment == "production" ? 3 : 1
  }
}

# Variables
variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "aws_region" {
  description = "AWS region for infrastructure"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_monitoring" {
  description = "Enable comprehensive monitoring stack"
  type        = bool
  default     = true
}

variable "enable_automation_scheduler" {
  description = "Enable automated scheduling components"
  type        = bool
  default     = true
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Random password for databases
resource "random_password" "automation_db_password" {
  length  = 32
  special = true
}

# VPC Configuration
resource "aws_vpc" "automation_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-vpc-${local.environment}"
    Type = "automation-infrastructure"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "automation_igw" {
  vpc_id = aws_vpc.automation_vpc.id
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-igw-${local.environment}"
  })
}

# Subnets
resource "aws_subnet" "automation_public_subnets" {
  count = min(length(data.aws_availability_zones.available.names), 3)
  
  vpc_id            = aws_vpc.automation_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  map_public_ip_on_launch = true
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-public-subnet-${count.index + 1}-${local.environment}"
    Type = "public"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "automation_private_subnets" {
  count = min(length(data.aws_availability_zones.available.names), 3)
  
  vpc_id            = aws_vpc.automation_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-private-subnet-${count.index + 1}-${local.environment}"
    Type = "private"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# Route Tables
resource "aws_route_table" "automation_public_rt" {
  vpc_id = aws_vpc.automation_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.automation_igw.id
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-public-rt-${local.environment}"
  })
}

resource "aws_route_table_association" "automation_public_rta" {
  count = length(aws_subnet.automation_public_subnets)
  
  subnet_id      = aws_subnet.automation_public_subnets[count.index].id
  route_table_id = aws_route_table.automation_public_rt.id
}

# NAT Gateway for private subnets
resource "aws_eip" "automation_nat_eip" {
  count = var.environment == "production" ? length(aws_subnet.automation_public_subnets) : 1
  
  domain = "vpc"
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-nat-eip-${count.index + 1}-${local.environment}"
  })
  
  depends_on = [aws_internet_gateway.automation_igw]
}

resource "aws_nat_gateway" "automation_nat_gw" {
  count = var.environment == "production" ? length(aws_subnet.automation_public_subnets) : 1
  
  allocation_id = aws_eip.automation_nat_eip[count.index].id
  subnet_id     = aws_subnet.automation_public_subnets[count.index].id
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-nat-gw-${count.index + 1}-${local.environment}"
  })
}

resource "aws_route_table" "automation_private_rt" {
  count = var.environment == "production" ? length(aws_subnet.automation_private_subnets) : 1
  
  vpc_id = aws_vpc.automation_vpc.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.automation_nat_gw[var.environment == "production" ? count.index : 0].id
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-private-rt-${count.index + 1}-${local.environment}"
  })
}

resource "aws_route_table_association" "automation_private_rta" {
  count = length(aws_subnet.automation_private_subnets)
  
  subnet_id      = aws_subnet.automation_private_subnets[count.index].id
  route_table_id = aws_route_table.automation_private_rt[var.environment == "production" ? count.index : 0].id
}

# Security Groups
resource "aws_security_group" "automation_control_plane_sg" {
  name_prefix = "${local.project_name}-control-plane-"
  vpc_id      = aws_vpc.automation_vpc.id
  
  # EKS Cluster control plane security group rules
  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS access from VPC"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-control-plane-sg-${local.environment}"
  })
}

resource "aws_security_group" "automation_worker_sg" {
  name_prefix = "${local.project_name}-worker-"
  vpc_id      = aws_vpc.automation_vpc.id
  
  # Worker node security group rules
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
    description = "All traffic within security group"
  }
  
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.automation_control_plane_sg.id]
    description     = "HTTPS from control plane"
  }
  
  ingress {
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.automation_control_plane_sg.id]
    description     = "High ports from control plane"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-worker-sg-${local.environment}"
  })
}

# RDS Subnet Group
resource "aws_db_subnet_group" "automation_db_subnet_group" {
  name       = "${local.project_name}-db-subnet-group-${local.environment}"
  subnet_ids = aws_subnet.automation_private_subnets[*].id
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-db-subnet-group-${local.environment}"
  })
}

# RDS Security Group
resource "aws_security_group" "automation_rds_sg" {
  name_prefix = "${local.project_name}-rds-"
  vpc_id      = aws_vpc.automation_vpc.id
  
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.automation_worker_sg.id]
    description     = "PostgreSQL from worker nodes"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-rds-sg-${local.environment}"
  })
}

# RDS Instance for automation data
resource "aws_db_instance" "automation_database" {
  identifier = "${local.project_name}-db-${local.environment}"
  
  engine          = "postgres"
  engine_version  = "15.4"
  instance_class  = var.environment == "production" ? "db.r6g.large" : "db.t3.micro"
  
  allocated_storage     = var.environment == "production" ? 100 : 20
  max_allocated_storage = var.environment == "production" ? 1000 : 100
  storage_type         = var.environment == "production" ? "gp3" : "gp2"
  storage_encrypted    = true
  
  db_name  = "automation"
  username = "automation_admin"
  password = random_password.automation_db_password.result
  
  vpc_security_group_ids = [aws_security_group.automation_rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.automation_db_subnet_group.name
  
  backup_retention_period = var.environment == "production" ? 30 : 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = var.environment != "production"
  deletion_protection = var.environment == "production"
  
  # Enable monitoring for production
  monitoring_interval = var.environment == "production" ? 60 : 0
  monitoring_role_arn = var.environment == "production" ? aws_iam_role.automation_rds_monitoring[0].arn : null
  
  # Enable performance insights
  performance_insights_enabled = var.environment == "production"
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-database-${local.environment}"
    Type = "automation-database"
  })
}

# IAM Role for RDS Enhanced Monitoring (production only)
resource "aws_iam_role" "automation_rds_monitoring" {
  count = var.environment == "production" ? 1 : 0
  
  name = "${local.project_name}-rds-monitoring-role-${local.environment}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "automation_rds_monitoring" {
  count = var.environment == "production" ? 1 : 0
  
  role       = aws_iam_role.automation_rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "automation_redis_subnet_group" {
  name       = "${local.project_name}-redis-subnet-group-${local.environment}"
  subnet_ids = aws_subnet.automation_private_subnets[*].id
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-redis-subnet-group-${local.environment}"
  })
}

# ElastiCache Security Group
resource "aws_security_group" "automation_redis_sg" {
  name_prefix = "${local.project_name}-redis-"
  vpc_id      = aws_vpc.automation_vpc.id
  
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.automation_worker_sg.id]
    description     = "Redis from worker nodes"
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-redis-sg-${local.environment}"
  })
}

# ElastiCache Redis Cluster
resource "aws_elasticache_replication_group" "automation_redis" {
  replication_group_id       = "${local.project_name}-redis-${local.environment}"
  description                = "Redis cluster for automation framework"
  
  node_type                  = var.environment == "production" ? "cache.r6g.large" : "cache.t3.micro"
  port                       = 6379
  parameter_group_name       = "default.redis7"
  
  num_cache_clusters         = var.environment == "production" ? 3 : 1
  
  subnet_group_name          = aws_elasticache_subnet_group.automation_redis_subnet_group.name
  security_group_ids         = [aws_security_group.automation_redis_sg.id]
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.automation_db_password.result
  
  automatic_failover_enabled = var.environment == "production"
  multi_az_enabled          = var.environment == "production"
  
  snapshot_retention_limit = var.environment == "production" ? 7 : 1
  snapshot_window         = "03:00-05:00"
  maintenance_window      = "sun:05:00-sun:07:00"
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-redis-${local.environment}"
    Type = "automation-cache"
  })
}

# EKS IAM Role
resource "aws_iam_role" "automation_eks_cluster_role" {
  name = "${local.project_name}-eks-cluster-role-${local.environment}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "automation_eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.automation_eks_cluster_role.name
}

# EKS Cluster
resource "aws_eks_cluster" "automation_cluster" {
  name     = "${local.project_name}-cluster-${local.environment}"
  role_arn = aws_iam_role.automation_eks_cluster_role.arn
  version  = "1.28"
  
  vpc_config {
    subnet_ids              = concat(aws_subnet.automation_public_subnets[*].id, aws_subnet.automation_private_subnets[*].id)
    security_group_ids      = [aws_security_group.automation_control_plane_sg.id]
    endpoint_private_access = true
    endpoint_public_access  = var.environment != "production"
    public_access_cidrs     = var.environment != "production" ? ["0.0.0.0/0"] : []
  }
  
  # Enable logging for production
  enabled_cluster_log_types = var.environment == "production" ? ["api", "audit", "authenticator", "controllerManager", "scheduler"] : []
  
  encryption_config {
    provider {
      key_arn = aws_kms_key.automation_kms_key.arn
    }
    resources = ["secrets"]
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.automation_eks_cluster_policy
  ]
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-cluster-${local.environment}"
    Type = "automation-kubernetes-cluster"
  })
}

# KMS Key for encryption
resource "aws_kms_key" "automation_kms_key" {
  description             = "KMS key for ${local.project_name} automation framework"
  deletion_window_in_days = var.environment == "production" ? 30 : 7
  enable_key_rotation     = true
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-kms-key-${local.environment}"
  })
}

resource "aws_kms_alias" "automation_kms_key_alias" {
  name          = "alias/${local.project_name}-${local.environment}"
  target_key_id = aws_kms_key.automation_kms_key.key_id
}

# Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.automation_vpc.id
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.automation_cluster.endpoint
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.automation_cluster.name
}

output "database_endpoint" {
  description = "Endpoint of the automation database"
  value       = aws_db_instance.automation_database.endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "Endpoint of the Redis cluster"
  value       = aws_elasticache_replication_group.automation_redis.primary_endpoint_address
  sensitive   = true
}

output "kms_key_id" {
  description = "ID of the KMS key for encryption"
  value       = aws_kms_key.automation_kms_key.key_id
}