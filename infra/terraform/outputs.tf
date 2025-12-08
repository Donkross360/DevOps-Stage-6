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

output "environment" {
  description = "Current environment"
  value       = var.environment
}

