#!/bin/bash
# Diagnostic script to identify duplicate EC2 instances

set -e

echo "🔍 Diagnosing Duplicate EC2 Instances"
echo "======================================"
echo ""

# Check for instances with the todo-app-server tag
echo "📋 Finding all instances with tag Name=todo-app-server:"
INSTANCES=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=todo-app-server" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,LaunchTime,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table 2>/dev/null || echo "ERROR: Could not query AWS")

if [ -z "$INSTANCES" ] || echo "$INSTANCES" | grep -q "ERROR"; then
  echo "❌ Failed to query AWS. Check your AWS credentials."
  exit 1
fi

echo "$INSTANCES"
echo ""

# Count instances
INSTANCE_COUNT=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=todo-app-server" "Name=instance-state-name,Values=running,stopped,stopping,pending" \
  --query 'length(Reservations[*].Instances[*])' \
  --output text 2>/dev/null || echo "0")

echo "📊 Total instances found: $INSTANCE_COUNT"
echo ""

if [ "$INSTANCE_COUNT" -gt 1 ]; then
  echo "⚠️  WARNING: Multiple instances detected!"
  echo ""
  echo "Possible causes:"
  echo "1. Terraform lifecycle 'create_before_destroy' created a new instance before destroying the old one"
  echo "2. Import failed, so Terraform created a new instance alongside the existing one"
  echo "3. Manual instance creation outside of Terraform"
  echo "4. Workflow ran multiple times concurrently"
  echo ""
  echo "🔧 Recommended actions:"
  echo ""
  echo "1. Check Terraform state:"
  echo "   cd infra/terraform"
  echo "   terraform state list | grep aws_instance"
  echo ""
  echo "2. Check if instances are in Terraform state:"
  echo "   terraform state show aws_instance.todo_app"
  echo ""
  echo "3. If you have duplicate instances:"
  echo "   - Identify which one is the 'correct' one (check creation time, IP, etc.)"
  echo "   - Import the correct one into Terraform state if not already there"
  echo "   - Remove the incorrect one from AWS (or terminate it)"
  echo ""
  echo "4. To prevent future duplicates:"
  echo "   - Ensure import logic runs before Terraform plan"
  echo "   - Check workflow concurrency settings"
  echo "   - Consider using 'prevent_destroy' lifecycle rule for production"
  echo ""
  
  # Get instance IDs
  INSTANCE_IDS=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=todo-app-server" "Name=instance-state-name,Values=running,stopped,stopping,pending" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text 2>/dev/null || echo "")
  
  if [ -n "$INSTANCE_IDS" ]; then
    echo "📝 Instance IDs found:"
    for INSTANCE_ID in $INSTANCE_IDS; do
      echo "   - $INSTANCE_ID"
      echo "     Launch time: $(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].LaunchTime' --output text 2>/dev/null || echo 'Unknown')"
      echo "     State: $(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo 'Unknown')"
      echo "     Public IP: $(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null || echo 'None')"
    done
  fi
else
  echo "✅ Only one instance found (or no instances). This is expected."
fi

echo ""
echo "======================================"
echo "Diagnosis complete."

