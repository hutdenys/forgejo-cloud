provider "aws" {
  region = "us-east-1"
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "my-tf-state-bucket535845769543"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = "my-tf-state-bucket535845769543"
    key    = "db/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "acm" {
  backend = "s3"
  config = {
    bucket = "my-tf-state-bucket535845769543"
    key    = "acm/terraform.tfstate"
    region = "us-east-1"
  }
}

# ECS Security Group
resource "aws_security_group" "ecs" {
  name        = "forgejo-ecs-sg"
  description = "Allow traffic from ALB to Forgejo container"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "forgejo-ecs-sg"
  }
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "forgejo-alb-sg"
  description = "Allow HTTP access to ALB"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

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

  tags = {
    Name = "forgejo-alb-sg"
  }
}

# ALB Module
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.17.0"

  name               = "forgejo-alb"
  load_balancer_type = "application"

  vpc_id  = data.terraform_remote_state.network.outputs.vpc_id
  subnets = data.terraform_remote_state.network.outputs.public_subnets

  security_groups            = [aws_security_group.alb.id]
  enable_deletion_protection = false

  target_groups = {
    forgejo = {
      name_prefix      = "fgj"
      backend_protocol = "HTTP"
      backend_port     = 3000
      target_type      = "ip"

      create_attachment = false

      health_check = {
        enabled             = true
        path                = "/fake"
        healthy_threshold   = 2
        unhealthy_threshold = 10
        timeout             = 2
        interval            = 300
        matcher             = "404"
      }
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = data.terraform_remote_state.acm.outputs.certificate_arn

      forward = {
        target_group_key = "forgejo"
      }
    }
  }

  tags = {
    Name = "forgejo-alb"
  }
}

# EFS Module
module "efs" {
  source = "../efs"

  name                  = "forgejo-efs"
  creation_token        = "forgejo-efs"
  vpc_id                = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids            = data.terraform_remote_state.network.outputs.private_subnets
  ecs_security_group_id = aws_security_group.ecs.id
}

# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = "forgejo-cluster"
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "forgejo-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_ecs_exec" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "ecs_exec_custom" {
  name        = "ECSExecCustomPolicy"
  description = "Allows ECS Exec functionality for SSM"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_custom_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.ecs_exec_custom.arn
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task" {
  name = "forgejo-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_efs_policy" {
  name = "forgejo-task-efs-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ],
        Resource = "*"
      }
    ]
  })
}


# Task Definition
resource "aws_ecs_task_definition" "forgejo" {
  family                   = "forgejo-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  volume {
    name = "forgejo-data"
    efs_volume_configuration {
      file_system_id     = module.efs.file_system_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = module.efs.access_point_id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "forgejo"
      image     = var.forgejo_image
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ],
      mountPoints = [
        {
          sourceVolume  = "forgejo-data"
          containerPath = "/data"
          readOnly      = false
        }
      ]
    }
  ])


}

# ECS Service
resource "aws_ecs_service" "forgejo" {
  name                   = "forgejo"
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.forgejo.arn
  launch_type            = "FARGATE"
  desired_count          = 1
  enable_execute_command = true

  network_configuration {
    subnets          = data.terraform_remote_state.network.outputs.public_subnets
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = module.alb.target_groups["forgejo"].arn
    container_name   = "forgejo"
    container_port   = 3000
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution,
    module.alb
  ]
}
