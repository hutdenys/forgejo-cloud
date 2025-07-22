terraform {
  backend "s3" {
    bucket = "my-tf-state-bucket535845769543"
    key    = "jenkins/terraform.tfstate"
    region = "us-east-1"
  }
}
