resource "aws_security_group" "aurora_sg" {
  name        = "AuroraSG"
  description = "Allow MySQL traffic within VPC"
  vpc_id      = aws_vpc.wordpress.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name = "AuroraSG"
  }
}

resource "aws_db_subnet_group" "aurora" {
  name       = "aurora-subnet-group"
  description = "Aurora private subnets"
  subnet_ids  = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]
}

resource "aws_rds_cluster" "aurora" {
  engine                  = "aurora-mysql"
  engine_mode             = "provisioned"
  engine_version          = "8.0.mysql_aurora.3.05.2"
  master_username         = var.db_username
  master_password         = var.db_password
  database_name           = var.db_name
  db_subnet_group_name    = aws_db_subnet_group.aurora.name
  vpc_security_group_ids  = [aws_security_group.aurora_sg.id]
  backup_retention_period = 1
  preferred_backup_window = "02:00-03:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  storage_encrypted       = true
}

resource "aws_rds_cluster_instance" "writer" {
  identifier         = "aurora-writer-instance"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.instance_class
  engine             = "aurora-mysql"
  publicly_accessible = false
  availability_zone   = "eu-south-2a"
}

resource "aws_rds_cluster_instance" "reader" {
  identifier         = "aurora-reader-instance"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.instance_class
  engine             = "aurora-mysql"
  publicly_accessible = false
  availability_zone   = "eu-south-2b"
}