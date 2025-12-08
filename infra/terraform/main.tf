terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Provider configuration
provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["*ubuntu-jammy-22.04-amd64-server*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Security Group
resource "aws_security_group" "todo_app" {
  name        = "todo-app-sg"
  description = "Security group for TODO application"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "todo-app-sg-${var.environment}"
    Environment = var.environment
  }
}

# Note: EBS volume for local state storage removed - using S3 remote backend instead

# EC2 Instance
resource "aws_instance" "todo_app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.todo_app.id]
  availability_zone      = var.availability_zone != "" ? var.availability_zone : null

  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    apt-get update
    apt-get install -y python3 python3-pip
  EOF

  tags = {
    Name        = "todo-app-server-${var.environment}"
    Environment = var.environment
    Project     = "hngi13-stage6"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Generate Ansible Inventory (per environment)
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    server_ip   = aws_instance.todo_app.public_ip
    server_user = var.server_user
    ssh_key_path = var.ssh_key_path
  })
  filename = "${path.module}/../ansible/inventory/${var.environment}.yml"
}

# Null resource to trigger Ansible (skipped in CI/CD - workflow handles it)
resource "null_resource" "ansible_provision" {
  # Skip in CI/CD environments - workflow handles Ansible deployment
  count = var.skip_ansible_provision ? 0 : 1
  
  triggers = {
    instance_id = aws_instance.todo_app.id
    inventory   = local_file.ansible_inventory.content
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for EC2 instance to be ready for SSH..."
      
      # Wait for instance to be in running state
      echo "Waiting for instance to reach running state..."
      aws ec2 wait instance-running --instance-ids ${aws_instance.todo_app.id} || true
      
      # Wait additional time for SSH to start
      echo "Waiting for SSH service to be available..."
      sleep 30
      
      # Wait for SSH to be actually accessible
      MAX_RETRIES=30
      RETRY_COUNT=0
      until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ${var.ssh_key_path} ${var.server_user}@${aws_instance.todo_app.public_ip} 'echo "SSH ready"' 2>/dev/null; do
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
          echo "WARNING: SSH connection failed after $MAX_RETRIES attempts"
          echo "Ansible will be handled by CI/CD workflow instead"
          exit 0  # Exit gracefully - workflow will handle it
        fi
        echo "Attempt $RETRY_COUNT/$MAX_RETRIES: SSH not ready yet, waiting 10 seconds..."
        sleep 10
      done
      
      echo "SSH is ready! Running Ansible..."
      cd ${path.module}/../ansible
      ansible-playbook -i inventory/${var.environment}.yml playbook.yml
    EOT
  }

  depends_on = [
    aws_instance.todo_app,
    local_file.ansible_inventory
  ]
}

