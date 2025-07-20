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

# EFS Module
module "efs" {
  source = "../efs"

  name                  = "forgejo-efs"
  creation_token        = "forgejo-efs"
  vpc_id                = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids            = data.terraform_remote_state.network.outputs.private_subnets
  ecs_security_group_id = module.ecs.ecs_security_group_id
}

# ELB Module
module "elb" {
  source = "./modules/elb"

  name_prefix     = "forgejo"
  vpc_id          = data.terraform_remote_state.network.outputs.vpc_id
  subnets         = data.terraform_remote_state.network.outputs.public_subnets
  certificate_arn = data.terraform_remote_state.acm.outputs.certificate_arn
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"

  name_prefix           = "forgejo"
  vpc_id                = data.terraform_remote_state.network.outputs.vpc_id
  subnets               = data.terraform_remote_state.network.outputs.public_subnets
  alb_security_group_id = module.elb.alb_security_group_id
  target_group_arn      = module.elb.target_group_arn
  container_image       = var.forgejo_image
  efs_file_system_id    = module.efs.file_system_id
  efs_access_point_id   = module.efs.access_point_id

  depends_on = [module.elb]
}
