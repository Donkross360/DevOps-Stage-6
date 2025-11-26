terraform {
  # CI/CD Backend: Local backend (state stored in CI/CD runner)
  # This works for CI/CD pipelines - state is ephemeral but functional
  # For persistence, you can migrate to EBS backend after first apply
  backend "local" {
    path = "terraform.tfstate"
  }
  
  # Optional: EBS-mounted backend (after EC2 instance exists)
  # If you want persistent state on the EC2 instance:
  # 1. After first apply, copy terraform.tfstate to the server:
  #    scp terraform.tfstate user@server-ip:/mnt/terraform-state/terraform.tfstate
  # 2. Uncomment the backend below
  # 3. Run: terraform init -migrate-state
  #
  # backend "local" {
  #   path = "/mnt/terraform-state/terraform.tfstate"
  # }
}

