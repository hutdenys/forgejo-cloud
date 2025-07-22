# Forgejo Cloud Infrastructure Management
# 
# Usage:
#   make help                    - Show this help
#   make scale COUNT=2           - Scale Forgejo to 2 containers
#   make scale-up                - Scale up by 1 container
#   make scale-down              - Scale down by 1 container
#   make status                  - Show current status
#   make logs                    - Show recent logs
#   make deploy-app              - Deploy/update app infrastructure
#   make deploy-jenkins          - Deploy/update Jenkins
#   make deploy-all              - Deploy all infrastructure
#   make destroy-all             - Destroy all infrastructure (careful!)

# Variables
AWS_REGION := us-east-1
ECS_CLUSTER := forgejo-cluster
ECS_SERVICE := forgejo
TERRAFORM_DIRS := network acm db efs app jenkins route53

.PHONY: help scale scale-up scale-down status logs deploy-app deploy-jenkins deploy-route53 deploy-all destroy-all check-dns

# Default target
help:
	@echo "Forgejo Cloud Infrastructure Management"
	@echo ""
	@echo "Scaling Commands:"
	@echo "  make scale COUNT=N     - Scale Forgejo service to N containers"
	@echo "  make scale-up          - Increase container count by 1"
	@echo "  make scale-down        - Decrease container count by 1"
	@echo ""
	@echo "Monitoring Commands:"
	@echo "  make status            - Show ECS service status"
	@echo "  make logs              - Show recent application logs"
	@echo "  make tasks             - List running tasks"
	@echo ""
	@echo "Deployment Commands:"
	@echo "  make deploy-app        - Deploy/update Forgejo application"
	@echo "  make deploy-jenkins    - Deploy/update Jenkins"
	@echo "  make deploy-route53    - Deploy/update Route 53 DNS"
	@echo "  make deploy-all        - Deploy all infrastructure modules"
	@echo ""
	@echo "Infrastructure Commands:"
	@echo "  make init-all          - Initialize all Terraform modules"
	@echo "  make plan-all          - Plan all Terraform modules"
	@echo "  make destroy-all       - Destroy all infrastructure"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make endpoints         - Show service endpoints"
	@echo "  make ssh-jenkins       - SSH to Jenkins instance"
	@echo "  make check-dns         - Check DNS resolution"

# Scaling commands
scale:
ifndef COUNT
	@echo "Error: COUNT parameter required"
	@echo "Usage: make scale COUNT=2"
	@exit 1
endif
	@echo "Scaling Forgejo service to $(COUNT) containers..."
	@aws ecs update-service \
		--cluster $(ECS_CLUSTER) \
		--service $(ECS_SERVICE) \
		--desired-count $(COUNT) \
		--region $(AWS_REGION)
	@echo "Scaling initiated. Use 'make status' to check progress."

scale-up:
	@echo "Scaling up Forgejo service..."
	@powershell -Command "\
		$$current = aws ecs describe-services --cluster $(ECS_CLUSTER) --services $(ECS_SERVICE) --region $(AWS_REGION) --query 'services[0].desiredCount' --output text; \
		$$new = [int]$$current + 1; \
		Write-Host \"Current: $$current → New: $$new\"; \
		aws ecs update-service --cluster $(ECS_CLUSTER) --service $(ECS_SERVICE) --desired-count $$new --region $(AWS_REGION) | Out-Null"
	@echo "Scaled up successfully!"

scale-down:
	@echo "Scaling down Forgejo service..."
	@powershell -Command "\
		$$current = aws ecs describe-services --cluster $(ECS_CLUSTER) --services $(ECS_SERVICE) --region $(AWS_REGION) --query 'services[0].desiredCount' --output text; \
		if ([int]$$current -le 0) { \
			Write-Host 'Cannot scale below 0 container'; \
			exit 1; \
		}; \
		$$new = [int]$$current - 1; \
		Write-Host \"Current: $$current → New: $$new\"; \
		aws ecs update-service --cluster $(ECS_CLUSTER) --service $(ECS_SERVICE) --desired-count $$new --region $(AWS_REGION) | Out-Null"
	@echo "Scaled down successfully!"

# Monitoring commands
status:
	@echo "=== ECS Service Status ==="
	@aws ecs describe-services \
		--cluster $(ECS_CLUSTER) \
		--services $(ECS_SERVICE) \
		--region $(AWS_REGION) \
		--query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}' \
		--output table
	
tasks:
	@echo "=== Running Tasks ==="
	@powershell -Command "\
		$$tasks = aws ecs list-tasks --cluster $(ECS_CLUSTER) --service-name $(ECS_SERVICE) --region $(AWS_REGION) --query 'taskArns[*]' --output text; \
		if ($$tasks -and $$tasks -ne 'None') { \
			$$tasks.Split([char]9) | ForEach-Object { \
				if ($$_.Trim()) { \
					aws ecs describe-tasks --cluster $(ECS_CLUSTER) --tasks $$_.Trim() --region $(AWS_REGION) --query 'tasks[0].{TaskId:taskArn,Status:lastStatus,Health:healthStatus,CreatedAt:createdAt}' --output table \
				} \
			} \
		} else { \
			Write-Host 'No tasks found' \
		}"

logs:
	@echo "=== Recent Application Logs ==="
	@aws logs tail /ecs/forgejo \
		--since 1h \
		--region $(AWS_REGION) \
		--follow

# Deployment commands
deploy-app:
	@echo "Deploying Forgejo application..."
	@cd app && terraform init && terraform apply -auto-approve
	@echo "Application deployed!"

deploy-jenkins:
	@echo "Deploying Jenkins..."
	@cd jenkins && terraform init && terraform apply -auto-approve
	@echo "Jenkins deployed!"

deploy-route53:
	@echo "Deploying Route 53 DNS..."
	@cd route53 && terraform init && terraform apply -auto-approve
	@echo "Route 53 deployed!"

deploy-all:
	@echo "Deploying all infrastructure..."
	@powershell -Command "\
		'$(TERRAFORM_DIRS)'.Split(' ') | ForEach-Object { \
			Write-Host \"Deploying $$_...\"; \
			Set-Location $$_; \
			terraform init; \
			terraform apply -auto-approve; \
			Set-Location ..; \
		}"
	@echo "All infrastructure deployed!"

# Infrastructure management
init-all:
	@echo "Initializing all Terraform modules..."
	@powershell -Command "\
		'$(TERRAFORM_DIRS)'.Split(' ') | ForEach-Object { \
			Write-Host \"Initializing $$_...\"; \
			Set-Location $$_; \
			terraform init; \
			Set-Location ..; \
		}"
	@echo "All modules initialized!"

plan-all:
	@echo "Planning all Terraform modules..."
	@powershell -Command "\
		'$(TERRAFORM_DIRS)'.Split(' ') | ForEach-Object { \
			Write-Host \"Planning $$_...\"; \
			Set-Location $$_; \
			terraform plan; \
			Set-Location ..; \
		}"

destroy-all:
	@echo "WARNING: This will destroy ALL infrastructure!"
	@powershell -Command "\
		$$confirm = Read-Host 'Type yes to confirm'; \
		if ($$confirm -ne 'yes') { \
			Write-Host 'Cancelled.'; \
			exit 1; \
		}"
	@echo "Destroying all infrastructure..."
	@powershell -Command "\
		$$dirs = '$(TERRAFORM_DIRS)'.Split(' '); \
		[array]::Reverse($$dirs); \
		$$dirs | ForEach-Object { \
			Write-Host \"Destroying $$_...\"; \
			Set-Location $$_; \
			terraform destroy -auto-approve; \
			Set-Location ..; \
		}"
	@echo "All infrastructure destroyed!"

# Utility commands
endpoints:
	@echo "=== Service Endpoints ==="
	@echo "Forgejo:"
	@powershell -Command "\
		Set-Location app; \
		$$output = terraform output alb_dns_name 2>$$null; \
		if ($$output) { \
			$$url = $$output.Trim('\"'); \
			Write-Host \"  http://$$url\"; \
		} else { \
			Write-Host '  Not deployed'; \
		}; \
		Set-Location .."
	@echo ""
	@echo "Jenkins:"
	@powershell -Command "\
		Set-Location jenkins; \
		$$output = terraform output jenkins_url 2>$$null; \
		if ($$output) { \
			$$url = $$output.Trim('\"'); \
			Write-Host \"  $$url\"; \
		} else { \
			Write-Host '  Not deployed'; \
		}; \
		Set-Location .."
	@echo ""
	@echo "DNS Records (Route 53):"
	@powershell -Command "\
		Set-Location route53; \
		$$forgejo = terraform output forgejo_fqdn 2>$$null; \
		if ($$forgejo) { \
			$$domain = $$forgejo.Trim('\"'); \
			Write-Host \"  Forgejo: https://$$domain\"; \
		}; \
		$$jenkins = terraform output jenkins_fqdn 2>$$null; \
		if ($$jenkins) { \
			$$domain = $$jenkins.Trim('\"'); \
			Write-Host \"  Jenkins: http://$$domain:8080\"; \
		}; \
		Set-Location .." 2>$null || echo "  Route 53 not deployed"

ssh-jenkins:
	@echo "Connecting to Jenkins instance..."
	@powershell -Command "\
		Set-Location jenkins; \
		$$ip = terraform output jenkins_public_ip 2>$$null; \
		if ($$ip) { \
			$$cleanIp = $$ip.Trim('\"'); \
			ssh -i jenkins-key.pem ec2-user@$$cleanIp; \
		} else { \
			Write-Host 'Jenkins not deployed or IP not found'; \
		}; \
		Set-Location .."

# Quick deployment order for new environments
quick-deploy:
	@echo "Quick deployment in correct order..."
	@powershell -Command "\
		$$modules = @('network', 'acm', 'db', 'efs', 'app', 'jenkins', 'route53'); \
		$$modules | ForEach-Object { \
			Set-Location $$_; \
			terraform init; \
			terraform apply -auto-approve; \
			Set-Location ..; \
		}"
	@echo "Quick deployment completed!"
	@make endpoints

# DNS verification
check-dns:
	@echo "=== DNS Resolution Check ==="
	@powershell -Command "\
		Set-Location route53; \
		$$forgejo = terraform output forgejo_fqdn 2>$$null; \
		if ($$forgejo) { \
			$$domain = $$forgejo.Trim('\"'); \
			Write-Host \"Checking Forgejo DNS: $$domain\"; \
			try { \
				$$result = Resolve-DnsName $$domain -Type A; \
				Write-Host \"  Resolved to: $$($result.IPAddress -join ', ')\"; \
			} catch { \
				Write-Host \"  DNS resolution failed: $$($_.Exception.Message)\"; \
			} \
		}; \
		$$jenkins = terraform output jenkins_fqdn 2>$$null; \
		if ($$jenkins) { \
			$$domain = $$jenkins.Trim('\"'); \
			Write-Host \"Checking Jenkins DNS: $$domain\"; \
			try { \
				$$result = Resolve-DnsName $$domain -Type A; \
				Write-Host \"  Resolved to: $$($result.IPAddress -join ', ')\"; \
			} catch { \
				Write-Host \"  DNS resolution failed: $$($_.Exception.Message)\"; \
			} \
		}; \
		Set-Location .." 2>$null || echo "Route 53 not deployed"
