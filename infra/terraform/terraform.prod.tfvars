# Production Environment Configuration
environment = "prod"

# AWS Configuration
aws_region     = "us-east-1"
instance_type  = "t3.medium"  # Or larger for production

# SSH Configuration
key_pair_name  = "hngtask1.pem"  # Update with your key pair name
ssh_key_path   = "~/.ssh/id_rsa"
ssh_cidr       = "0.0.0.0/0"  # IMPORTANT: Restrict to your IP in production (e.g., "1.2.3.4/32")
server_user    = "ubuntu"

# Availability Zone
availability_zone = ""

# Skip Ansible provisioner in CI/CD
skip_ansible_provision = true


