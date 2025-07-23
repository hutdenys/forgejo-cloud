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

  manage_master_user_password = false

  vpc_security_group_ids = [data.terraform_remote_state.network.outputs.rds_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  create_db_subnet_group = false

  publicly_accessible = false
  skip_final_snapshot = true

  tags = {
    Name = "forgejo-db"
  }
}
