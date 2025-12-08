# Infrastructure as Code - Multi-Environment Setup

This directory contains Terraform and Ansible configurations for deploying the TODO application across multiple environments (dev, staging, production).

## Directory Structure

```
infra/
├── terraform/          # Infrastructure provisioning with Terraform
│   ├── main.tf         # Main Terraform configuration
│   ├── variables.tf    # Variable definitions
│   ├── outputs.tf      # Output values
│   ├── backend.tf      # Remote state backend (S3 + DynamoDB)
│   ├── terraform.dev.tfvars    # Development environment variables
│   ├── terraform.stg.tfvars    # Staging environment variables
│   ├── terraform.prod.tfvars   # Production environment variables
│   └── templates/      # Terraform templates
├── ansible/            # Server configuration and application deployment
│   ├── playbook.yml    # Main Ansible playbook
│   ├── inventory/      # Ansible inventory files (per environment)
│   │   ├── dev.yml.example
│   │   ├── stg.yml.example
│   │   └── prod.yml.example
│   ├── group_vars/     # Environment-specific variables
│   │   ├── all/        # Common variables for all environments
│   │   ├── dev/        # Development-specific variables
│   │   ├── stg/        # Staging-specific variables
│   │   └── prod/       # Production-specific variables
│   └── roles/          # Ansible roles
│       ├── dependencies/  # Install Docker, Docker Compose, etc.
│       └── deploy/        # Deploy application with docker-compose
└── ci-cd/              # CI/CD scripts and documentation
```

## Prerequisites

### 1. AWS Resources

Before deploying, you need:

- **S3 Bucket**: For Terraform state storage
  - Create bucket: `aws s3 mb s3://your-terraform-state-bucket`
  - Enable versioning: `aws s3api put-bucket-versioning --bucket your-terraform-state-bucket --versioning-configuration Status=Enabled`
  
- **DynamoDB Table**: For state locking
  - Create table: `aws dynamodb create-table --table-name terraform-state-lock --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST`

### 2. GitHub Secrets

Configure these secrets in your GitHub repository:

```
TERRAFORM_STATE_BUCKET=<your-s3-bucket-name>
TERRAFORM_STATE_LOCK_TABLE=<your-dynamodb-table-name>
AWS_ACCESS_KEY_ID=<your-aws-access-key>
AWS_SECRET_ACCESS_KEY=<your-aws-secret-key>
AWS_REGION=us-east-1
TERRAFORM_KEY_PAIR_NAME=<your-aws-key-pair-name>
SSH_PRIVATE_KEY=<your-ssh-private-key>
EMAIL_TO=<your-email>
EMAIL_FROM=<your-email>
```

### 3. Local Setup (for manual deployment)

- Terraform >= 1.5.0
- Ansible >= 2.9
- AWS CLI configured
- SSH key pair in AWS

## Environment Configuration

### Terraform Variables

Each environment has its own `.tfvars` file:

- **Development** (`terraform.dev.tfvars`): Smaller instance, permissive SSH
- **Staging** (`terraform.stg.tfvars`): Medium instance, testing configuration
- **Production** (`terraform.prod.tfvars`): Production instance, restricted SSH

Key differences:
- `instance_type`: Varies by environment (t3.small for dev, t3.medium for stg/prod)
- `environment`: Automatically set to dev/stg/prod
- `ssh_cidr`: Should be restricted in production

### Ansible Variables

Environment-specific variables are in `ansible/group_vars/{env}/vars.yml`:

- **Domain**: Different domains per environment (e.g., `dev.example.com`, `stg.example.com`, `example.com`)
- **SSL Email**: Let's Encrypt email address
- **JWT Secret**: Different secrets per environment (important for security!)
- **Repository**: Can point to different branches per environment

## Deployment Methods

### 1. CI/CD Workflows (Recommended)

#### Infrastructure Deployment

Triggered when files in `infra/terraform/**` or `infra/ansible/**` change:

```yaml
# Manual trigger with environment selection
workflow_dispatch:
  inputs:
    environment: [dev, stg, prod]
```

**Features:**
- Automatic drift detection
- Email alerts on real drift (infrastructure changed outside Terraform)
- Manual approval required for **prod** environment drift
- Auto-approval for dev/stg expected changes
- Remote state in S3 (per environment)

#### Application Deployment

Triggered when application code changes:

```yaml
# Manual trigger with environment selection
workflow_dispatch:
  inputs:
    environment: [dev, stg, prod]
```

**Features:**
- Idempotent deployment (only restarts if code/config changed)
- Environment-specific inventory
- Automatic docker-compose updates

### 2. Manual Local Deployment

#### Single Command Deployment

As required by the task, the entire setup works with a single command:

```bash
# One-time initialization (only needed once)
cd infra/terraform
terraform init \
  -backend-config="bucket=your-terraform-state-bucket" \
  -backend-config="key=terraform-state/dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=terraform-state-lock" \
  -backend-config="encrypt=true"

# Single command that does everything:
terraform apply -var-file=terraform.dev.tfvars -auto-approve
```

This single command will:
- ✅ Provision the cloud server (EC2 instance, security groups)
- ✅ Generate Ansible inventory file dynamically
- ✅ Run Ansible automatically (install dependencies, deploy application)
- ✅ Configure Traefik + SSL
- ✅ Skip unchanged resources (idempotent)

**Important**: The provided `terraform.{dev,stg,prod}.tfvars` files have `skip_ansible_provision = true` for CI/CD compatibility. For local single-command deployment, either:

1. **Override the variable** (recommended):
   ```bash
   terraform apply -var-file=terraform.dev.tfvars \
     -var="skip_ansible_provision=false" \
     -auto-approve
   ```

2. **Or create a local tfvars** (e.g., `terraform.dev.local.tfvars`):
   ```hcl
   # Copy from terraform.dev.tfvars but change:
   skip_ansible_provision = false
   ```
   Then use: `terraform apply -var-file=terraform.dev.local.tfvars -auto-approve`

#### Step-by-Step (Alternative)

1. **Provision Infrastructure:**
   ```bash
   cd infra/terraform
   terraform init -backend-config=...  # See above
   terraform plan -var-file=terraform.dev.tfvars
   terraform apply -var-file=terraform.dev.tfvars
   ```

2. **Deploy Application:**
   ```bash
   cd ../ansible
   # Inventory is generated by Terraform at infra/ansible/inventory/{env}.yml
   ansible-playbook -i inventory/dev.yml playbook.yml
   ```

## Remote State Management

### State Storage

- **Location**: S3 bucket with per-environment keys
  - Dev: `terraform-state/dev/terraform.tfstate`
  - Staging: `terraform-state/stg/terraform.tfstate`
  - Production: `terraform-state/prod/terraform.tfstate`

- **Locking**: DynamoDB table prevents concurrent modifications

### State Access

State is automatically managed by workflows. For local access:

```bash
terraform init \
  -backend-config="bucket=your-bucket" \
  -backend-config="key=terraform-state/dev/terraform.tfstate" \
  -backend-config="dynamodb_table=terraform-state-lock" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true"
```

## Drift Detection

The infrastructure workflow automatically detects drift:

1. **Expected Changes**: Terraform files were modified → Auto-apply (dev/stg) or require approval (prod)
2. **Real Drift**: Infrastructure changed outside Terraform → Email alert + Manual approval required
3. **No Changes**: Infrastructure in sync → Skip apply

**Manual Approval:**
- **Dev/Staging**: Auto-approve for expected changes, manual for drift
- **Production**: Manual approval required for ALL changes (expected or drift)

## Idempotent Deployments

The Ansible deploy role is idempotent:

- **Only rebuilds** when:
  - Git repository has new commits (code changed)
  - `.env` file changed (configuration changed)
  
- **Always pulls** latest images (checks for updates)

- **Only restarts** containers if:
  - Images were rebuilt
  - Containers need to be recreated
  - Configuration changed

This means running the playbook multiple times without changes will not restart services unnecessarily.

## Environment Isolation

Each environment is completely isolated:

- **Separate EC2 instances**: `todo-app-server-{env}`
- **Separate security groups**: `todo-app-sg-{env}`
- **Separate state files**: Per-environment S3 keys
- **Separate domains**: Configured in Ansible group_vars
- **Separate secrets**: JWT secrets per environment

## Troubleshooting

### State Lock Issues

If Terraform is stuck with a lock:

```bash
# Check lock in DynamoDB
aws dynamodb get-item \
  --table-name terraform-state-lock \
  --key '{"LockID":{"S":"your-bucket/terraform-state/dev/terraform.tfstate-md5"}}'

# Force unlock (use with caution!)
terraform force-unlock <LOCK_ID>
```

### Import Existing Resources

If resources exist outside Terraform:

```bash
# Import EC2 instance
terraform import -var-file=terraform.dev.tfvars aws_instance.todo_app i-xxxxx

# Import security group
terraform import -var-file=terraform.dev.tfvars aws_security_group.todo_app sg-xxxxx
```

### Ansible Connection Issues

```bash
# Test SSH connection
ansible all -i inventory/dev.yml -m ping

# Run with verbose output
ansible-playbook -i inventory/dev.yml playbook.yml -vvv
```

## Best Practices

1. **Never commit secrets**: Use GitHub Secrets or environment variables
2. **Always use remote state**: Never commit `terraform.tfstate` files
3. **Test in dev first**: Deploy to dev/stg before production
4. **Review drift alerts**: Investigate any unexpected infrastructure changes
5. **Use different secrets**: Each environment should have unique JWT secrets
6. **Restrict SSH in prod**: Set `ssh_cidr` to your IP in production tfvars

## Destroying Infrastructure

Use the destroy workflow in GitHub Actions:

1. Go to Actions → Infrastructure Destruction
2. Select environment (dev/stg/prod)
3. Type "DESTROY" to confirm
4. Review the destruction plan
5. Approve to proceed

**Warning**: This will destroy ALL resources for the selected environment!

## Additional Resources

- [GitHub Secrets Setup](./ci-cd/GITHUB_SECRETS_SETUP.md)
- [Workflow Optimization](./ci-cd/WORKFLOW_OPTIMIZATION.md)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Ansible Documentation](https://docs.ansible.com/)

