variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_pair_name" {
  description = "AWS Key Pair name"
  type        = string
}

variable "ssh_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "ssh_cidr" {
  description = "CIDR block for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "server_user" {
  description = "SSH user for server"
  type        = string
  default     = "ubuntu"
}

variable "state_volume_size" {
  description = "Size of EBS volume for Terraform state storage (GB)"
  type        = number
  default     = 10
}

variable "availability_zone" {
  description = "Availability zone for EC2 instance and EBS volume (optional, auto-selected if not specified)"
  type        = string
  default     = ""
}

variable "skip_ansible_provision" {
  description = "Skip Ansible provisioner (useful in CI/CD where workflow handles it separately)"
  type        = bool
  default     = false
}

