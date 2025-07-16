terraform {
  backend "s3" {
    bucket         = "my-tf-state-bucket535845769543"
    key            = "network/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
