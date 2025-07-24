output "volume_id" {
  description = "ID of the persistent EBS volume"
  value       = aws_ebs_volume.jenkins_home.id
}

output "volume_arn" {
  description = "ARN of the persistent EBS volume"
  value       = aws_ebs_volume.jenkins_home.arn
}

output "volume_size" {
  description = "Size of the EBS volume"
  value       = aws_ebs_volume.jenkins_home.size
}

output "availability_zone" {
  description = "Availability zone of the EBS volume"
  value       = aws_ebs_volume.jenkins_home.availability_zone
}
