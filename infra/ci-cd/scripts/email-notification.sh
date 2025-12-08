#!/bin/bash
# Email Notification Script for Terraform Drift
# Sends email alert when infrastructure drift is detected
# Uses AWS SES (Simple Email Service) - free tier: 62,000 emails/month

set -e

DRIFT_SUMMARY="${1:-}"

if [ -z "$DRIFT_SUMMARY" ]; then
  echo "Error: Drift summary not provided"
  exit 1
fi

# Email configuration from environment variables
EMAIL_TO="${EMAIL_TO:-}"
EMAIL_FROM="${EMAIL_FROM:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# GitHub Actions variables for workflow link
GITHUB_SERVER_URL="${GITHUB_SERVER_URL:-https://github.com}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
GITHUB_RUN_ID="${GITHUB_RUN_ID:-}"

# Check if email is configured
if [ -z "$EMAIL_TO" ]; then
  echo "⚠️  EMAIL_TO not configured. Skipping email notification."
  echo "Drift Summary:"
  echo "$DRIFT_SUMMARY"
  exit 0
fi

if [ -z "$EMAIL_FROM" ]; then
  echo "⚠️  EMAIL_FROM not configured. Skipping email notification."
  echo "Set EMAIL_FROM secret to your verified AWS SES email address."
  exit 0
fi

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
  echo "⚠️  AWS CLI not available. Skipping email notification."
  echo "Drift Summary:"
  echo "$DRIFT_SUMMARY"
  exit 0
fi

# Build workflow run URL if GitHub variables are available
WORKFLOW_URL=""
if [ -n "$GITHUB_REPOSITORY" ] && [ -n "$GITHUB_RUN_ID" ]; then
  WORKFLOW_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
fi

# Create email body
SUBJECT="🚨 Terraform Drift Detected - Action Required"
BODY=$(cat <<EOF
Terraform infrastructure drift has been detected.

This means infrastructure was changed OUTSIDE of Terraform (e.g., manually in AWS Console).

Please review the changes and approve the deployment in GitHub Actions.

$(if [ -n "$WORKFLOW_URL" ]; then echo "🔗 View Workflow Run: $WORKFLOW_URL"; echo ""; fi)

Drift Summary:
$DRIFT_SUMMARY

---
This is an automated message from GitHub Actions.
EOF
)

# Send email via AWS SES
echo "📧 Sending drift alert email via AWS SES..."
echo "From: $EMAIL_FROM"
echo "To: $EMAIL_TO"
echo "Region: $AWS_REGION"

# Escape double quotes for AWS SES
SES_BODY=$(echo "$BODY" | sed 's/"/\\"/g')
SES_SUBJECT=$(echo "$SUBJECT" | sed 's/"/\\"/g')

# Send email
if aws ses send-email \
  --region "$AWS_REGION" \
  --from "$EMAIL_FROM" \
  --to "$EMAIL_TO" \
  --subject "$SES_SUBJECT" \
  --text "$SES_BODY" 2>&1; then
  echo "✅ Email sent successfully via AWS SES"
  exit 0
else
  ERROR_CODE=$?
  echo "❌ Failed to send email via AWS SES"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Verify EMAIL_FROM is a verified email in AWS SES"
  echo "     → Go to AWS Console → SES → Verified identities"
  echo "  2. Check if AWS SES is in sandbox mode (can only send to verified emails)"
  echo "     → In sandbox mode, EMAIL_TO must also be verified"
  echo "  3. Verify AWS credentials are configured correctly"
  echo "  4. Check AWS SES sending limits"
  echo ""
  echo "Drift Summary:"
  echo "$DRIFT_SUMMARY"
  exit $ERROR_CODE
fi

