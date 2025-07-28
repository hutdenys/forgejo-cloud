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

output "jenkins_ebs_volume_id" {
  description = "EBS volume ID used for Jenkins home"
  value       = data.terraform_remote_state.ebs_jenkins.outputs.volume_id
}

output "jenkins_security_group_id" {
  description = "Security Group ID for Jenkins master"
  value       = data.terraform_remote_state.network.outputs.jenkins_security_group_id
}

output "jenkins_agents_security_group_id" {
  description = "Security Group ID for Jenkins agents"
  value       = data.terraform_remote_state.network.outputs.jenkins_agents_security_group_id
}

output "jenkins_subnet_id" {
  description = "Subnet ID for Jenkins agents (public subnet for internet access)"
  value       = data.terraform_remote_state.network.outputs.public_subnets[0]
}

output "jenkins_subnet_ids" {
  description = "All available subnet IDs for Jenkins agents"
  value       = data.terraform_remote_state.network.outputs.public_subnets
}

output "jenkins_iam_instance_profile" {
  description = "IAM Instance Profile name for Jenkins EC2 agents"
  value       = aws_iam_instance_profile.jenkins_ec2_profile.name
}
