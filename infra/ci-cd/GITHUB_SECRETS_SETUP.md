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

### 2. Terraform Variables (Required for Infrastructure)

#### `TERRAFORM_KEY_PAIR_NAME`
- **Description**: Name of your AWS Key Pair (must exist in AWS)
- **How to get**: AWS Console → EC2 → Key Pairs → Copy the name
- **Example**: `my-key-pair`, `todo-app-key`
- **Important**: This must match an existing Key Pair in your AWS account

#### `TERRAFORM_INSTANCE_TYPE` (Optional)
- **Description**: EC2 instance type
- **Default**: `t3.medium` (if not set)
- **Example**: `t3.micro`, `t3.small`, `t3.medium`

#### `TERRAFORM_SSH_CIDR` (Optional)
- **Description**: CIDR block for SSH access
- **Default**: `0.0.0.0/0` (if not set - allows SSH from anywhere)
- **Example**: `0.0.0.0/0`, `1.2.3.4/32` (restrict to your IP)

#### `TERRAFORM_STATE_VOLUME_SIZE` (Optional)
- **Description**: Size of EBS volume for Terraform state (GB)
- **Default**: `10` (if not set)
- **Example**: `10`, `20`

### 3. SSH Private Key (Required for Ansible)

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

#### `EMAIL_TO` (Optional - for email notifications)
- **Description**: Email address to receive Terraform drift notifications
- **Example**: `your-email@example.com`
- **Note**: Must be verified in AWS SES if SES is in sandbox mode

#### `EMAIL_FROM` (Optional - for email notifications)
- **Description**: Email address to send from (must be verified in AWS SES)
- **How to verify in AWS SES**:
  1. Go to AWS Console → SES → Verified identities
  2. Click "Create identity"
  3. Choose "Email address"
  4. Enter your email address
  5. Click "Create identity"
  6. Check your email inbox and click the verification link
  7. Copy your verified email address
- **Example**: `your-email@example.com`
- **Important**: This email MUST be verified in AWS SES before emails can be sent

---

## Email Configuration (AWS SES - Free Tier)

We use **AWS SES (Simple Email Service)** for email notifications:
- ✅ **Free**: 62,000 emails/month free tier
- ✅ **No additional signups**: Uses your existing AWS account
- ✅ **Integrated**: Already using AWS for infrastructure
- ✅ **Reliable**: Managed by AWS

### Setup Steps:

1. **Verify sender email in AWS SES**:
   - Go to: AWS Console → SES → Verified identities
   - Click "Create identity" → Choose "Email address"
   - Enter your email → Click "Create identity"
   - Check your email and click the verification link

2. **Verify recipient email** (only if SES is in sandbox mode):
   - Repeat step 1 for your recipient email
   - **Note**: In sandbox mode, you can only send to verified emails
   - To send to any email: Request production access in SES dashboard

3. **Set GitHub Secrets**:
   - `EMAIL_TO`: Email address to receive notifications
   - `EMAIL_FROM`: Your verified email in AWS SES

That's it! Uses your existing AWS credentials (already configured).

### AWS SES Sandbox Mode:

- **Sandbox mode** (default): Can only send to verified email addresses
  - Both `EMAIL_FROM` and `EMAIL_TO` must be verified initially
- **Production access**: Can send to any email address
  - Request in SES → Account dashboard → "Request production access"
  - Usually approved within 24 hours

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

### Required Secrets:
- [ ] `AWS_ACCESS_KEY_ID` - AWS access key
- [ ] `AWS_SECRET_ACCESS_KEY` - AWS secret key
- [ ] `TERRAFORM_KEY_PAIR_NAME` - AWS Key Pair name
- [ ] `SSH_PRIVATE_KEY` - SSH private key matching your AWS Key Pair

### Optional Secrets (for email notifications):
- [ ] `EMAIL_TO` - Email address to receive drift notifications
- [ ] `EMAIL_FROM` - Verified email in AWS SES (to send from)

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

### Email not sending
- **Verify emails in AWS SES**: Both `EMAIL_FROM` and `EMAIL_TO` must be verified if in sandbox mode
- **Check sandbox mode**: In AWS SES dashboard, check if you're in sandbox (can only send to verified emails)
- **Request production access**: To send to any email, request production access in SES dashboard
- **Check workflow logs**: Look for email sending errors in "Send Drift Email" step
- **Verify AWS credentials**: Ensure AWS credentials have SES permissions
- **Test email**: Try sending a test email manually via AWS CLI: `aws ses send-email --from your@email.com --to your@email.com --subject "Test" --text "Test"`

