# GitHub Secrets Setup Guide

This guide explains how to set up GitHub Secrets for the CI/CD workflows.

## Required Secrets

### 1. AWS Credentials (Required for Terraform)

Go to: **Repository → Settings → Secrets and variables → Actions → New repository secret**

#### `AWS_ACCESS_KEY_ID`
- **Description**: Your AWS Access Key ID
- **How to get**: AWS Console → IAM → Users → Your User → Security credentials → Create access key
- **Example**: `AKIAIOSFODNN7EXAMPLE`

#### `AWS_SECRET_ACCESS_KEY`
- **Description**: Your AWS Secret Access Key (paired with the Access Key ID)
- **How to get**: Created together with Access Key ID (only shown once - save it!)
- **Example**: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`

#### `AWS_REGION` (Optional)
- **Description**: AWS region where resources will be created
- **Default**: `us-east-1` (if not set)
- **Example**: `us-east-1`, `us-west-2`, `eu-west-1`

### 2. SSH Private Key (Required for Ansible)

#### `SSH_PRIVATE_KEY`
- **Description**: Your SSH private key for connecting to the EC2 instance
- **How to get**: 
  - If you have a `.pem` file: `cat ~/.ssh/your-key.pem`
  - Or the key that matches the AWS Key Pair you specified in `terraform.tfvars`
- **Format**: Full contents of your private key file, including:
  ```
  -----BEGIN RSA PRIVATE KEY-----
  [key content]
  -----END RSA PRIVATE KEY-----
  ```
  Or:
  ```
  -----BEGIN OPENSSH PRIVATE KEY-----
  [key content]
  -----END OPENSSH PRIVATE KEY-----
  ```

### 3. Email Notification (Optional - for Drift Detection)

#### `EMAIL_TO`
- **Description**: Email address to receive Terraform drift notifications
- **Example**: `your-email@example.com`

#### `SMTP_USER` (Optional)
- **Description**: SMTP username for sending emails (if using SMTP)
- **Note**: Currently, email notification uses GitHub API. SMTP support can be added if needed.

#### `SMTP_PASS` (Optional)
- **Description**: SMTP password for sending emails

---

## Setup Steps

1. **Go to your GitHub repository**
   - Navigate to: `https://github.com/YOUR_USERNAME/DevOps-Stage-6`

2. **Open Secrets Settings**
   - Click: **Settings** → **Secrets and variables** → **Actions**

3. **Add each secret**
   - Click: **New repository secret**
   - Enter the **Name** (exactly as shown above)
   - Enter the **Value**
   - Click: **Add secret**

4. **Verify secrets are added**
   - You should see all required secrets listed
   - Secret values are hidden (you can only see names)

---

## Quick Checklist

- [ ] `AWS_ACCESS_KEY_ID` - AWS access key
- [ ] `AWS_SECRET_ACCESS_KEY` - AWS secret key
- [ ] `AWS_REGION` - AWS region (optional, defaults to us-east-1)
- [ ] `SSH_PRIVATE_KEY` - SSH private key matching your AWS Key Pair

---

## Security Notes

1. **Never commit secrets to the repository**
   - All sensitive values should be in GitHub Secrets only
   - The `.env` and `terraform.tfvars` files are in `.gitignore`

2. **SSH Key Permissions**
   - Ensure your SSH key has `chmod 600` permissions locally
   - GitHub Actions will set correct permissions automatically

3. **AWS IAM Permissions**
   - Your AWS access key should have permissions for:
     - EC2 (create instances, security groups, volumes)
     - VPC (if using custom VPC)
   - Recommended: Create an IAM user with minimal required permissions

4. **Rotate Secrets Regularly**
   - Periodically rotate AWS access keys
   - Update GitHub Secrets when keys are rotated

---

## Testing Secrets

After setting up secrets, you can test them by:

1. **Push changes to trigger workflow**
   ```bash
   git push origin main
   ```

2. **Or manually trigger**
   - Go to: **Actions** → **Infrastructure Deployment** → **Run workflow**

3. **Check workflow logs**
   - Go to: **Actions** → Click on the workflow run
   - Look for errors related to missing secrets

---

## Troubleshooting

### "AWS credentials not found"
- Verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set correctly
- Check IAM user has necessary permissions

### "Permission denied (publickey)" in Ansible
- Verify `SSH_PRIVATE_KEY` matches your AWS Key Pair
- Ensure the key format is correct (including BEGIN/END lines)
- Check the key isn't password-protected (or use `ssh-agent` if it is)

### "terraform.tfstate not found" in Application workflow
- Run the Infrastructure workflow first to create the EC2 instance
- The Application workflow depends on Terraform state

