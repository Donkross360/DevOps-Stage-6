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
    Name = "todo-app-sg"
  }
}

# EBS Volume for Terraform State Storage
resource "aws_ebs_volume" "terraform_state" {
  availability_zone = aws_instance.todo_app.availability_zone
  size              = var.state_volume_size
  type              = "gp3"
  encrypted         = true
  
  tags = {
    Name        = "terraform-state-storage"
    Purpose     = "Terraform state storage"
    Environment = "production"
  }
}

# Attach EBS Volume to EC2 Instance
resource "aws_volume_attachment" "terraform_state" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.terraform_state.id
  instance_id = aws_instance.todo_app.id
  
  # Prevent detachment during instance replacement
  skip_destroy = false
  force_detach = true
}

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
    
    # Wait for EBS volume to attach
    echo "Waiting for EBS volume to attach..."
    while [ ! -b /dev/xvdf ] && [ ! -b /dev/nvme1n1 ]; do
      sleep 2
    done
    
    # Determine device name (varies by instance type)
    if [ -b /dev/nvme1n1 ]; then
      DEVICE="/dev/nvme1n1"
    elif [ -b /dev/xvdf ]; then
      DEVICE="/dev/xvdf"
    else
      echo "EBS volume not found"
      exit 1
    fi
    
    # Create filesystem if it doesn't exist
    if ! blkid $DEVICE > /dev/null 2>&1; then
      echo "Creating filesystem on $DEVICE..."
      mkfs -t ext4 $DEVICE
    fi
    
    # Create mount point
    mkdir -p /mnt/terraform-state
    
    # Mount the volume
    mount $DEVICE /mnt/terraform-state
    
    # Make mount persistent
    UUID=$(blkid -s UUID -o value $DEVICE)
    if ! grep -q "$UUID" /etc/fstab; then
      echo "UUID=$UUID /mnt/terraform-state ext4 defaults,nofail 0 2" >> /etc/fstab
    fi
    
    # Set permissions
    chown ${var.server_user}:${var.server_user} /mnt/terraform-state
    chmod 755 /mnt/terraform-state
    
    echo "EBS volume mounted successfully at /mnt/terraform-state"
  EOF

  tags = {
    Name        = "todo-app-server"
    Environment = "production"
    Project     = "hngi13-stage6"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Generate Ansible Inventory
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    server_ip   = aws_instance.todo_app.public_ip
    server_user = var.server_user
    ssh_key_path = var.ssh_key_path
  })
  filename = "${path.module}/../ansible/inventory/hosts.yml"
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
      ansible-playbook -i inventory/hosts.yml playbook.yml
    EOT
  }

  depends_on = [
    aws_instance.todo_app,
    local_file.ansible_inventory
  ]
}

