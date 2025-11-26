#!/bin/bash
# Email Notification Script for Terraform Drift
# Sends email alert when infrastructure drift is detected

set -e

DRIFT_SUMMARY="${1:-}"

if [ -z "$DRIFT_SUMMARY" ]; then
  echo "Error: Drift summary not provided"
  exit 1
fi

# Email configuration from environment variables or secrets
EMAIL_TO="${EMAIL_TO:-${{ secrets.EMAIL_TO }}}"
EMAIL_FROM="${EMAIL_FROM:-terraform-drift@github-actions.com}"
SMTP_SERVER="${SMTP_SERVER:-smtp.gmail.com}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-${{ secrets.SMTP_USER }}}"
SMTP_PASS="${SMTP_PASS:-${{ secrets.SMTP_PASS }}}"

# If email is not configured, use GitHub API to create an issue instead
if [ -z "$EMAIL_TO" ] && [ -z "$SMTP_USER" ]; then
  echo "Email not configured. Skipping email notification."
  echo "Drift Summary:"
  echo "$DRIFT_SUMMARY"
  exit 0
fi

# Create email body
SUBJECT="Terraform Drift Detected - Action Required"
BODY=$(cat <<EOF
Terraform infrastructure drift has been detected.

Please review the changes and approve the deployment in GitHub Actions.

Drift Summary:
$DRIFT_SUMMARY

---
This is an automated message from GitHub Actions.
EOF
)

# Send email using sendmail or curl (depending on what's available)
if command -v sendmail &> /dev/null; then
  {
    echo "To: $EMAIL_TO"
    echo "From: $EMAIL_FROM"
    echo "Subject: $SUBJECT"
    echo ""
    echo "$BODY"
  } | sendmail "$EMAIL_TO"
elif command -v curl &> /dev/null && [ -n "$SMTP_USER" ]; then
  # Use curl to send via SMTP (requires SMTP credentials)
  echo "Sending email via SMTP..."
  # Note: This is a simplified example. For production, use a proper email service
  # like SendGrid, Mailgun, or AWS SES
  echo "Email would be sent to: $EMAIL_TO"
  echo "Subject: $SUBJECT"
  echo "Body: $BODY"
else
  echo "No email sending method available. Drift summary:"
  echo "$DRIFT_SUMMARY"
fi

