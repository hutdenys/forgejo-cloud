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

data "terraform_remote_state" "efs" {
  backend = "s3"
  config = {
    bucket = "my-tf-state-bucket535845769543"
    key    = "efs/terraform.tfstate"
    region = "us-east-1"
  }
}

# ELB Module
module "elb" {
  source = "./modules/elb"

  name_prefix           = "forgejo"
  vpc_id                = data.terraform_remote_state.network.outputs.vpc_id
  subnets               = data.terraform_remote_state.network.outputs.public_subnets
  certificate_arn       = data.terraform_remote_state.acm.outputs.certificate_arn
  alb_security_group_id = data.terraform_remote_state.network.outputs.alb_security_group_id
  jenkins_domain        = var.jenkins_domain
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"

  name_prefix           = "forgejo"
  vpc_id                = data.terraform_remote_state.network.outputs.vpc_id
  subnets               = data.terraform_remote_state.network.outputs.public_subnets
  alb_security_group_id = data.terraform_remote_state.network.outputs.alb_security_group_id
  ecs_security_group_id = data.terraform_remote_state.network.outputs.ecs_security_group_id
  target_group_arn      = module.elb.target_group_arn
  container_image       = var.forgejo_image
  assign_public_ip      = true
  efs_file_system_id    = data.terraform_remote_state.efs.outputs.file_system_id
  efs_access_point_id   = data.terraform_remote_state.efs.outputs.access_point_id

  depends_on = [module.elb]
}
