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

resource "aws_security_group" "ecs" {
  name        = "forgejo-ecs-sg"
  description = "Allow inbound to Forgejo container"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Make private or restrict later
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

resource "aws_ecs_cluster" "this" {
  name = "forgejo-cluster"
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "forgejo-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "forgejo" {
  family                   = "forgejo-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name  = "forgejo"
      image = var.forgejo_image
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ],
      environment = [
        { name = "FORGEJO__database__DB_TYPE", value = "mysql" },
        { name = "FORGEJO__database__HOST", value = data.terraform_remote_state.db.outputs.db_endpoint },
        { name = "FORGEJO__database__NAME", value = var.db_name },
        { name = "FORGEJO__database__USER", value = var.db_username },
        { name = "FORGEJO__database__PASSWD", value = var.db_password }
      ]
    }
  ])
}

resource "aws_ecs_service" "forgejo" {
  name            = "forgejo"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.forgejo.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = data.terraform_remote_state.network.outputs.public_subnets
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_task_execution]
}
