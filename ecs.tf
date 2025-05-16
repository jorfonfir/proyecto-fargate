resource "aws_security_group" "wordpress_sg" {
  name        = "wordpress_sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.wordpress.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "mysql_sg" {
  name        = "mysql_sg"
  description = "Allow MySQL traffic from WordPress"
  vpc_id      = aws_vpc.wordpress.id

  ingress {
    from_port         = 3306
    to_port           = 3306
    protocol          = "tcp"
    security_groups   = [aws_security_group.wordpress_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_efs_file_system" "wordpress_efs" {
  creation_token = "wordpress-efs"
  performance_mode = var.efs_performance_mode
  throughput_mode  = var.efs_throughput_mode
  encrypted        = true
}

resource "aws_efs_mount_target" "wordpress_mount_target" {
  file_system_id = aws_efs_file_system.wordpress_efs.id
  subnet_id      = aws_subnet.private_1.id
  security_groups = [aws_security_group.wordpress_sg.id]
}

resource "aws_ecs_cluster" "wordpress_cluster" {
  name = "wordpress-cluster"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_ecs_task_definition" "wordpress_task" {
  family                   = "wordpress-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn      = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn
  container_definitions   = jsonencode([{
    name      = "wordpress"
    image     = "wordpress:latest"
    essential = true
    environment = [
      {
        name  = "WORDPRESS_DB_HOST"
        value = "aurora-cluster.cluster-xyz.us-east-1.rds.amazonaws.com"
      },
      {
        name  = "WORDPRESS_DB_NAME"
        value = var.db_name
      },
      {
        name  = "WORDPRESS_DB_USER"
        value = var.db_username
      },
      {
        name  = "WORDPRESS_DB_PASSWORD"
        value = var.db_password
      }
    ]
    mountPoints = [
      {
        containerPath = "/var/www/html"
        sourceVolume  = "wordpress_data"
      }
    ]
  }])

  volume {
    name = "wordpress_data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.wordpress_efs.id
      root_directory = "/"
    }
  }
}

resource "aws_ecs_service" "wordpress_service" {
  name            = "wordpress-service"
  cluster         = aws_ecs_cluster.wordpress_cluster.id
  task_definition = aws_ecs_task_definition.wordpress_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id] # Cambia a subredes públicas
    security_groups  = [aws_security_group.wordpress_sg.id]
    assign_public_ip = true # Esto es CLAVE para tener salida a Internet
  }
}

resource "aws_lb" "wordpress_alb" {
  name               = "wordpress-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups   = [aws_security_group.wordpress_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "wordpress_tg" {
  name     = "wordpress-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.wordpress.id
}

resource "aws_lb_listener" "wordpress_listener" {
  load_balancer_arn = aws_lb.wordpress_alb.arn
  port              = 80
  default_action {
    type             = "fixed-response"
    fixed_response {
      status_code = 200
      content_type = "text/plain"
      message_body = "OK"
    }
  }
}