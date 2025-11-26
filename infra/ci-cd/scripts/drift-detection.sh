#!/bin/bash
# Drift Detection Script
# This script analyzes Terraform plan output to detect infrastructure drift

set -e

PLAN_FILE="${1:-tfplan}"
DRIFT_SUMMARY="${2:-drift_summary.txt}"

if [ ! -f "$PLAN_FILE" ]; then
  echo "Error: Plan file $PLAN_FILE not found"
  exit 1
fi

# Check if there are any changes
if terraform show -no-color "$PLAN_FILE" | grep -q "No changes"; then
  echo "No drift detected - infrastructure is in sync"
  exit 0
else
  echo "Drift detected - infrastructure changes found"
  terraform show -no-color "$PLAN_FILE" > "$DRIFT_SUMMARY"
  exit 1
fi

