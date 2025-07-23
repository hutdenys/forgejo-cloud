output "jenkins_public_ip" {
  description = "Public IP address of Jenkins"
  value       = aws_eip.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${aws_eip.jenkins.public_ip}:8080"
}

output "jenkins_ssh_command" {
  description = "SSH command to connect to Jenkins"
  value       = "ssh -i ${var.key_pair_name}.pem ec2-user@${aws_eip.jenkins.public_ip}"
}

output "jenkins_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.jenkins.id
}
