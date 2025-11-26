output "server_ip" {
  description = "Public IP of the server"
  value       = aws_instance.todo_app.public_ip
}

output "server_dns" {
  description = "Public DNS of the server"
  value       = aws_instance.todo_app.public_dns
}

output "ansible_inventory_path" {
  description = "Path to generated Ansible inventory"
  value       = local_file.ansible_inventory.filename
}

output "state_volume_id" {
  description = "EBS volume ID for Terraform state storage"
  value       = aws_ebs_volume.terraform_state.id
}

output "state_mount_path" {
  description = "Mount path for Terraform state on EC2 instance"
  value       = "/mnt/terraform-state"
}

