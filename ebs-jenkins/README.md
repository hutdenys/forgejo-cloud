# Persistent EBS Volume for Jenkins

This module creates a persistent EBS volume for Jenkins home directory that will survive terraform destroy operations.

## Features

- Persistent EBS volume with lifecycle protection
- GP3 volume type with configurable IOPS and throughput
- Encryption enabled by default
- Separate state management for independent lifecycle

## Usage

1. First, create the persistent EBS volume:
```bash
cd ebs-jenkins
terraform init
terraform plan
terraform apply
```

2. Note the volume ID from the output, then use it in the Jenkins module.

## Outputs

- `volume_id`: ID of the created EBS volume
- `volume_arn`: ARN of the EBS volume
- `volume_size`: Size of the volume
- `availability_zone`: AZ where the volume is created

## Important Notes

- The EBS volume has `prevent_destroy` lifecycle rule to prevent accidental deletion
- The volume must be in the same AZ as the Jenkins EC2 instance
- To actually delete the volume, you need to remove the `prevent_destroy` rule first
