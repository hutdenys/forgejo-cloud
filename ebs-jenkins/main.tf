provider "aws" {
  region = var.aws_region
}

# Persistent EBS Volume for Jenkins Home
resource "aws_ebs_volume" "jenkins_home" {
  availability_zone = var.availability_zone
  size              = var.volume_size
  type              = var.volume_type
  encrypted         = var.encrypted
  iops              = var.iops
  throughput        = var.throughput

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.tags, {
    Name       = var.volume_name
    Purpose    = "Jenkins Home Directory"
    Persistent = "true"
  })
}
