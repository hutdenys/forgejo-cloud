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

resource "aws_security_group" "rds" {
  name        = "forgejo-rds-sg"
  description = "Allow access to RDS"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Replace with more secure rule later
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "forgejo-rds-sg"
  }
}

resource "aws_db_subnet_group" "rds" {
  name       = "forgejo-db-subnet-group"
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnets

  tags = {
    Name = "forgejo-db-subnet-group"
  }
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.5.2"

  identifier           = "forgejo-db"
  engine               = "mariadb"
  engine_version       = "10.6"
  major_engine_version = "10.6"
  family               = "mariadb10.6"
  instance_class       = var.db_instance_class
  allocated_storage    = 20
  storage_encrypted    = false
  username             = var.db_username
  password             = var.db_password
  db_name              = var.db_name
  port                 = 3306

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  create_db_subnet_group = false

  publicly_accessible = false
  skip_final_snapshot = true

  tags = {
    Name = "forgejo-db"
  }
}
